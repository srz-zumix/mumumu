import AVFoundation
import CoreImage
import Flutter
import UIKit

/// 無音キャプチャに関するエラー。
enum SilentCameraError: LocalizedError {
    case deviceNotFound
    case sessionNotReady
    case encodingFailed
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .deviceNotFound:
            return "利用できるカメラが見つかりません。"
        case .sessionNotReady:
            return "カメラの準備ができていません。"
        case .encodingFailed:
            return "画像の生成に失敗しました。"
        case .saveFailed(let message):
            return message
        }
    }
}

/// `AVCaptureVideoDataOutput` のフレームをプレビュー兼キャプチャ源として扱うセッション。
///
/// `AVCapturePhotoOutput` を使う写真モードでは、日本・韓国向け端末で OS が
/// シャッター音を鳴らすため、既定はフレーム切り出しによる無音モードとする。
final class CameraSession: NSObject {

    private let registry: FlutterTextureRegistry
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "dev.srzzumix.silent_camera.session")
    private let bufferQueue = DispatchQueue(label: "dev.srzzumix.silent_camera.buffer")
    private let ciContext = CIContext()

    private var device: AVCaptureDevice?
    private var textureId: Int64 = 0
    private var latestBuffer: CVPixelBuffer?
    private var silentMode = true
    private var lensDirection = "back"
    private var photoDelegate: PhotoCaptureDelegate?

    init(registry: FlutterTextureRegistry) {
        self.registry = registry
        super.init()
    }

    /// 利用できるカメラの一覧。
    static func availableCameras() -> [[String: Any]] {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInWideAngleCamera,
                .builtInUltraWideCamera,
                .builtInTelephotoCamera,
                .builtInDualCamera,
                .builtInTripleCamera
            ],
            mediaType: .video,
            position: .unspecified
        )
        var seen = Set<String>()
        return discovery.devices.compactMap { device -> [String: Any]? in
            let direction = lensDirectionName(device.position)
            guard !seen.contains(direction) else { return nil }
            seen.insert(direction)
            return describe(device: device, direction: direction)
        }
    }

    /// セッションを開始する。
    func start(
        lensDirection: String,
        captureMode: String,
        aspectRatio: String,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        self.lensDirection = lensDirection
        silentMode = captureMode != "photo"
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            do {
                let device = try self.selectDevice(lensDirection: lensDirection)
                self.device = device
                self.captureSession.beginConfiguration()
                self.captureSession.sessionPreset = Self.preset(for: aspectRatio)

                self.captureSession.inputs.forEach { self.captureSession.removeInput($0) }
                let input = try AVCaptureDeviceInput(device: device)
                guard self.captureSession.canAddInput(input) else {
                    throw SilentCameraError.deviceNotFound
                }
                self.captureSession.addInput(input)

                if !self.captureSession.outputs.contains(self.videoOutput) {
                    self.videoOutput.alwaysDiscardsLateVideoFrames = true
                    self.videoOutput.videoSettings = [
                        kCVPixelBufferPixelFormatTypeKey as String:
                            kCVPixelFormatType_32BGRA
                    ]
                    self.videoOutput.setSampleBufferDelegate(self, queue: self.bufferQueue)
                    if self.captureSession.canAddOutput(self.videoOutput) {
                        self.captureSession.addOutput(self.videoOutput)
                    }
                }
                if !self.silentMode, self.captureSession.canAddOutput(self.photoOutput) {
                    self.captureSession.addOutput(self.photoOutput)
                }
                self.captureSession.commitConfiguration()
                self.captureSession.startRunning()

                if self.textureId == 0 {
                    self.textureId = self.registry.register(self)
                }
                let info = self.sessionInfo(device: device)
                DispatchQueue.main.async { completion(.success(info)) }
            } catch {
                self.captureSession.commitConfiguration()
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    /// セッションを停止し、テクスチャを解放する。
    func stop() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
            self.videoOutput.setSampleBufferDelegate(nil, queue: nil)
            self.captureSession.inputs.forEach { self.captureSession.removeInput($0) }
        }
        if textureId != 0 {
            registry.unregisterTexture(textureId)
            textureId = 0
        }
        bufferQueue.sync { latestBuffer = nil }
    }

    /// フラッシュ（トーチ）動作を設定する。
    func setFlashMode(_ mode: String) {
        configureDevice { device in
            guard device.hasTorch else { return }
            switch mode {
            case "torch", "on":
                if device.isTorchModeSupported(.on) { device.torchMode = .on }
            case "auto":
                if device.isTorchModeSupported(.auto) { device.torchMode = .auto }
            default:
                device.torchMode = .off
            }
        }
    }

    /// ズーム倍率を設定する。
    func setZoomLevel(_ zoom: Double) {
        configureDevice { device in
            let clamped = min(
                max(CGFloat(zoom), device.minAvailableVideoZoomFactor),
                device.maxAvailableVideoZoomFactor
            )
            device.videoZoomFactor = clamped
        }
    }

    /// プレビュー座標（0.0〜1.0）にフォーカスと露出を合わせる。
    func setFocusPoint(x: Double, y: Double) {
        let point = CGPoint(x: min(max(x, 0), 1), y: min(max(y, 0), 1))
        configureDevice { device in
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = point
                if device.isFocusModeSupported(.autoFocus) {
                    device.focusMode = .autoFocus
                }
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
                if device.isExposureModeSupported(.autoExpose) {
                    device.exposureMode = .autoExpose
                }
            }
        }
    }

    /// AE/AF ロックを設定する。
    func setFocusExposureLocked(_ locked: Bool) {
        configureDevice { device in
            if locked {
                if device.isFocusModeSupported(.locked) { device.focusMode = .locked }
                if device.isExposureModeSupported(.locked) { device.exposureMode = .locked }
            } else {
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }
            }
        }
    }

    /// 露出補正（EV）を設定する。
    func setExposureOffset(_ offset: Double) {
        configureDevice { device in
            let clamped = min(
                max(Float(offset), device.minExposureTargetBias),
                device.maxExposureTargetBias
            )
            device.setExposureTargetBias(clamped, completionHandler: nil)
        }
    }

    /// 静止画を切り出してフォトライブラリへ保存する。
    func capture(
        format: String,
        quality: Int,
        mirrorFrontCamera: Bool,
        library: PhotoLibrarySaver,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        let mirror = mirrorFrontCamera && lensDirection == "front"
        if silentMode {
            captureFromVideoFrame(
                format: format,
                quality: quality,
                mirror: mirror,
                library: library,
                completion: completion
            )
        } else {
            capturePhoto(
                format: format,
                quality: quality,
                mirror: mirror,
                library: library,
                completion: completion
            )
        }
    }

    private func captureFromVideoFrame(
        format: String,
        quality: Int,
        mirror: Bool,
        library: PhotoLibrarySaver,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        bufferQueue.async { [weak self] in
            guard let self = self, let buffer = self.latestBuffer else {
                DispatchQueue.main.async { completion(.failure(SilentCameraError.sessionNotReady)) }
                return
            }
            var image = CIImage(cvPixelBuffer: buffer)
            if mirror {
                image = image.transformed(by: CGAffineTransform(scaleX: -1, y: 1))
                    .transformed(by: CGAffineTransform(translationX: image.extent.width, y: 0))
            }
            guard let data = self.encode(image: image, format: format, quality: quality) else {
                DispatchQueue.main.async { completion(.failure(SilentCameraError.encodingFailed)) }
                return
            }
            library.save(
                data: data,
                width: Int(image.extent.width),
                height: Int(image.extent.height),
                isHeic: format == "heic",
                completion: completion
            )
        }
    }

    private func capturePhoto(
        format: String,
        quality: Int,
        mirror: Bool,
        library: PhotoLibrarySaver,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        let settings: AVCapturePhotoSettings
        if format == "heic",
           photoOutput.availablePhotoCodecTypes.contains(.hevc) {
            settings = AVCapturePhotoSettings(
                format: [AVVideoCodecKey: AVVideoCodecType.hevc]
            )
        } else {
            settings = AVCapturePhotoSettings(
                format: [AVVideoCodecKey: AVVideoCodecType.jpeg]
            )
        }
        let delegate = PhotoCaptureDelegate { [weak self] result in
            self?.photoDelegate = nil
            switch result {
            case .success(let data):
                library.save(
                    data: data.data,
                    width: data.width,
                    height: data.height,
                    isHeic: format == "heic",
                    completion: completion
                )
            case .failure(let error):
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
        photoDelegate = delegate
        photoOutput.capturePhoto(with: settings, delegate: delegate)
    }

    private func encode(image: CIImage, format: String, quality: Int) -> Data? {
        let colorSpace = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        let compression = max(0.5, min(1.0, Double(quality) / 100.0))
        let options: [CIImageRepresentationOption: Any] = [
            kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption:
                compression
        ]
        if format == "heic" {
            return ciContext.heifRepresentation(
                of: image,
                format: .RGBA8,
                colorSpace: colorSpace,
                options: options
            )
        }
        return ciContext.jpegRepresentation(
            of: image,
            colorSpace: colorSpace,
            options: options
        )
    }

    private func sessionInfo(device: AVCaptureDevice) -> [String: Any] {
        let dimensions = CMVideoFormatDescriptionGetDimensions(
            device.activeFormat.formatDescription
        )
        return [
            "textureId": textureId,
            "previewWidth": Double(dimensions.width),
            "previewHeight": Double(dimensions.height),
            "captureMode": silentMode ? "silent" : "photo",
            "minExposureOffset": Double(device.minExposureTargetBias),
            "maxExposureOffset": Double(device.maxExposureTargetBias),
            "camera": Self.describe(
                device: device,
                direction: Self.lensDirectionName(device.position)
            )
        ]
    }

    private func selectDevice(lensDirection: String) throws -> AVCaptureDevice {
        let position: AVCaptureDevice.Position = lensDirection == "front" ? .front : .back
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInTripleCamera,
                .builtInDualCamera,
                .builtInWideAngleCamera
            ],
            mediaType: .video,
            position: position
        )
        guard let device = discovery.devices.first else {
            throw SilentCameraError.deviceNotFound
        }
        return device
    }

    private func configureDevice(_ block: (AVCaptureDevice) -> Void) {
        guard let device = device else { return }
        do {
            try device.lockForConfiguration()
            block(device)
            device.unlockForConfiguration()
        } catch {
            // 設定できない端末では現在の状態を維持する。
        }
    }

    private static func preset(for aspectRatio: String) -> AVCaptureSession.Preset {
        switch aspectRatio {
        case "ratio16x9":
            return .hd1920x1080
        default:
            // 4:3 / 1:1 は 4:3 のフォーマットから切り出す。
            return .photo
        }
    }

    private static func lensDirectionName(_ position: AVCaptureDevice.Position) -> String {
        switch position {
        case .front:
            return "front"
        case .back:
            return "back"
        default:
            return "external"
        }
    }

    private static func describe(device: AVCaptureDevice, direction: String) -> [String: Any] {
        var presets: [Double] = []
        if device.minAvailableVideoZoomFactor <= 0.6 {
            presets.append(0.5)
        }
        presets.append(1.0)
        for candidate in [2.0, 5.0] where candidate <= Double(device.maxAvailableVideoZoomFactor) {
            presets.append(candidate)
        }
        return [
            "id": device.uniqueID,
            "lensDirection": direction,
            "minZoom": Double(device.minAvailableVideoZoomFactor),
            "maxZoom": Double(device.maxAvailableVideoZoomFactor),
            "zoomPresets": presets
        ]
    }
}

extension CameraSession: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        latestBuffer = buffer
        if textureId != 0 {
            registry.textureFrameAvailable(textureId)
        }
    }
}

extension CameraSession: FlutterTexture {
    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        var buffer: CVPixelBuffer?
        bufferQueue.sync { buffer = latestBuffer }
        guard let buffer = buffer else { return nil }
        return Unmanaged.passRetained(buffer)
    }
}

/// `AVCapturePhotoOutput` の結果を受け取るデリゲート。
final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {

    struct Output {
        let data: Data
        let width: Int
        let height: Int
    }

    private let completion: (Result<Output, Error>) -> Void

    init(completion: @escaping (Result<Output, Error>) -> Void) {
        self.completion = completion
        super.init()
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error = error {
            completion(.failure(error))
            return
        }
        guard let data = photo.fileDataRepresentation() else {
            completion(.failure(SilentCameraError.encodingFailed))
            return
        }
        completion(
            .success(
                Output(
                    data: data,
                    width: Int(photo.resolvedSettings.photoDimensions.width),
                    height: Int(photo.resolvedSettings.photoDimensions.height)
                )
            )
        )
    }
}
