import AVFoundation
import CoreImage
import Flutter
import UIKit

/// 撮影セッション。プレビュー用テクスチャの供給と静止画の切り出しを行う。
final class SilentCameraSession: NSObject {
  enum SessionError: LocalizedError {
    case deviceNotFound
    case inputUnavailable
    case outputUnavailable
    case noFrameAvailable
    case encodingFailed

    var errorDescription: String? {
      switch self {
      case .deviceNotFound: return "利用可能なカメラが見つかりませんでした。"
      case .inputUnavailable: return "カメラ入力を構成できませんでした。"
      case .outputUnavailable: return "カメラ出力を構成できませんでした。"
      case .noFrameAvailable: return "プレビューのフレームを取得できませんでした。"
      case .encodingFailed: return "画像の書き出しに失敗しました。"
      }
    }
  }

  private let lensDirection: LensDirection
  private let resolution: CaptureResolution
  private let captureMode: CaptureMode

  private let captureSession = AVCaptureSession()
  private let videoOutput = AVCaptureVideoDataOutput()
  private let photoOutput = AVCapturePhotoOutput()
  private let sessionQueue = DispatchQueue(label: "dev.zumix.mumumu.silent_camera.session")
  private let bufferQueue = DispatchQueue(label: "dev.zumix.mumumu.silent_camera.buffer")
  private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

  private var device: AVCaptureDevice?
  private var deviceInput: AVCaptureDeviceInput?
  private var latestBuffer: CVPixelBuffer?
  private let bufferLock = NSLock()
  private var isPreviewPaused = false
  private var flashMode: FlashMode = .off
  private var photoCaptureDelegate: PhotoCaptureDelegate?

  private weak var textureRegistry: FlutterTextureRegistry?
  private(set) var textureId: Int64 = 0

  init(lensDirection: LensDirection, resolution: CaptureResolution, captureMode: CaptureMode) {
    self.lensDirection = lensDirection
    self.resolution = resolution
    self.captureMode = captureMode
    super.init()
  }

  // MARK: - Setup

  func configure() throws {
    guard let device = CameraEnumerator.bestDevice(for: lensDirection) else {
      throw SessionError.deviceNotFound
    }
    self.device = device

    captureSession.beginConfiguration()
    defer { captureSession.commitConfiguration() }

    applyPreset()

    guard let input = try? AVCaptureDeviceInput(device: device),
      captureSession.canAddInput(input)
    else {
      throw SessionError.inputUnavailable
    }
    captureSession.addInput(input)
    deviceInput = input

    videoOutput.videoSettings = [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
    ]
    videoOutput.alwaysDiscardsLateVideoFrames = true
    videoOutput.setSampleBufferDelegate(self, queue: bufferQueue)
    guard captureSession.canAddOutput(videoOutput) else {
      throw SessionError.outputUnavailable
    }
    captureSession.addOutput(videoOutput)

    if captureMode == .photo, captureSession.canAddOutput(photoOutput) {
      captureSession.addOutput(photoOutput)
    }

    configureConnections()
  }

  private func applyPreset() {
    for preset in resolution.fallbackPresets where captureSession.canSetSessionPreset(preset) {
      captureSession.sessionPreset = preset
      return
    }
    captureSession.sessionPreset = .high
  }

  /// プレビュー・撮影の向きと反転を設定する。
  ///
  /// 縦位置基準でフレームを受け取ることで、切り出した静止画の向きも揃う。
  private func configureConnections() {
    for output in captureSession.outputs {
      for connection in output.connections where connection.isVideoOrientationSupported {
        if #available(iOS 17.0, *) {
          if connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
          }
        } else {
          connection.videoOrientation = .portrait
        }
        if connection.isVideoMirroringSupported {
          connection.automaticallyAdjustsVideoMirroring = false
          connection.isVideoMirrored = (lensDirection == .front)
        }
      }
    }
  }

  func attach(registry: FlutterTextureRegistry, textureId: Int64) {
    self.textureRegistry = registry
    self.textureId = textureId
  }

  func start() {
    sessionQueue.async { [weak self] in
      guard let self = self, !self.captureSession.isRunning else { return }
      self.captureSession.startRunning()
    }
  }

  func stop() {
    setTorch(enabled: false)
    videoOutput.setSampleBufferDelegate(nil, queue: nil)
    sessionQueue.async { [weak self] in
      guard let self = self, self.captureSession.isRunning else { return }
      self.captureSession.stopRunning()
    }
    bufferLock.lock()
    latestBuffer = nil
    bufferLock.unlock()
  }

  func pausePreview() {
    isPreviewPaused = true
  }

  func resumePreview() {
    isPreviewPaused = false
  }

  func initializationMap() -> [String: Any] {
    let dimensions = activePortraitDimensions()
    let device = self.device
    return [
      "textureId": textureId,
      "previewWidth": Double(dimensions.width),
      "previewHeight": Double(dimensions.height),
      "description": device.map { CameraEnumerator.description(of: $0).toMap() } ?? [:],
      "minExposureOffset": Double(device?.minExposureTargetBias ?? 0),
      "maxExposureOffset": Double(device?.maxExposureTargetBias ?? 0),
      // iOS の露出補正は連続値のため刻み幅は 0 とする。
      "exposureOffsetStep": 0.0,
    ]
  }

  private func activePortraitDimensions() -> (width: Int32, height: Int32) {
    guard let device = device else { return (1080, 1920) }
    let dims = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
    // センサーは横長で出力されるため、縦位置基準に入れ替える。
    return (dims.height, dims.width)
  }

  // MARK: - Camera controls

  func setZoomLevel(_ zoom: CGFloat) throws {
    guard let device = device else { throw SessionError.deviceNotFound }
    try device.lockForConfiguration()
    defer { device.unlockForConfiguration() }
    let clamped = min(max(zoom, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
    device.videoZoomFactor = clamped
  }

  func setFocusAndExposurePoint(_ point: CGPoint) throws {
    guard let device = device else { throw SessionError.deviceNotFound }
    try device.lockForConfiguration()
    defer { device.unlockForConfiguration() }

    // プレビューは縦位置で表示しているため、センサー座標系へ変換する。
    var sensorPoint = CGPoint(x: point.y, y: 1.0 - point.x)
    if lensDirection == .front {
      sensorPoint = CGPoint(x: sensorPoint.x, y: 1.0 - sensorPoint.y)
    }

    if device.isFocusPointOfInterestSupported {
      device.focusPointOfInterest = sensorPoint
    }
    if device.isFocusModeSupported(.autoFocus) {
      device.focusMode = .autoFocus
    }
    if device.isExposurePointOfInterestSupported {
      device.exposurePointOfInterest = sensorPoint
    }
    if device.isExposureModeSupported(.autoExpose) {
      device.exposureMode = .autoExpose
    }
  }

  func setFocusAndExposureLocked(_ locked: Bool) throws {
    guard let device = device else { throw SessionError.deviceNotFound }
    try device.lockForConfiguration()
    defer { device.unlockForConfiguration() }

    let focusMode: AVCaptureDevice.FocusMode = locked ? .locked : .continuousAutoFocus
    if device.isFocusModeSupported(focusMode) {
      device.focusMode = focusMode
    }
    let exposureMode: AVCaptureDevice.ExposureMode = locked ? .locked : .continuousAutoExposure
    if device.isExposureModeSupported(exposureMode) {
      device.exposureMode = exposureMode
    }
  }

  func setExposureOffset(_ offset: Float) throws {
    guard let device = device else { throw SessionError.deviceNotFound }
    try device.lockForConfiguration()
    defer { device.unlockForConfiguration() }
    let clamped = min(max(offset, device.minExposureTargetBias), device.maxExposureTargetBias)
    device.setExposureTargetBias(clamped, completionHandler: nil)
  }

  func setFlashMode(_ mode: FlashMode) throws {
    flashMode = mode
    // 静音撮影ではフラッシュ発光の代わりにトーチを用いる。
    setTorch(enabled: mode == .torch)
  }

  private func setTorch(enabled: Bool) {
    guard let device = device, device.hasTorch, device.isTorchAvailable else { return }
    guard (try? device.lockForConfiguration()) != nil else { return }
    defer { device.unlockForConfiguration() }
    device.torchMode = enabled ? .on : .off
  }

  /// 撮影時にトーチ照射が必要かどうかを判定する。
  private func needsTorchForCapture() -> Bool {
    switch flashMode {
    case .off:
      return false
    case .on:
      return true
    case .torch:
      return false  // すでに点灯済み。
    case .auto:
      guard let device = device else { return false }
      // 露出時間と ISO から暗所かどうかを推定する。
      let iso = device.iso
      return iso >= device.activeFormat.maxISO * 0.6
    }
  }

  // MARK: - Capture

  func capture(options: CaptureOptions, completion: @escaping (Result<[String: Any], Error>) -> Void)
  {
    if captureMode == .photo {
      capturePhoto(options: options, completion: completion)
    } else {
      captureVideoFrame(options: options, completion: completion)
    }
  }

  private func captureVideoFrame(
    options: CaptureOptions,
    completion: @escaping (Result<[String: Any], Error>) -> Void
  ) {
    let useTorch = needsTorchForCapture()
    if useTorch {
      setTorch(enabled: true)
    }

    // トーチ点灯直後は露出が安定しないため、わずかに待ってからフレームを取得する。
    let delay: DispatchTimeInterval = useTorch ? .milliseconds(220) : .milliseconds(0)
    sessionQueue.asyncAfter(deadline: .now() + delay) { [weak self] in
      guard let self = self else { return }
      defer {
        if useTorch { self.setTorch(enabled: false) }
      }

      self.bufferLock.lock()
      let buffer = self.latestBuffer
      self.bufferLock.unlock()

      guard let pixelBuffer = buffer else {
        completion(.failure(SessionError.noFrameAvailable))
        return
      }

      do {
        let map = try self.encode(pixelBuffer: pixelBuffer, options: options)
        completion(.success(map))
      } catch {
        completion(.failure(error))
      }
    }
  }

  private func capturePhoto(
    options: CaptureOptions,
    completion: @escaping (Result<[String: Any], Error>) -> Void
  ) {
    let settings = AVCapturePhotoSettings()
    if photoOutput.supportedFlashModes.contains(flashMode.avFlashMode) {
      settings.flashMode = flashMode.avFlashMode
    }

    let delegate = PhotoCaptureDelegate { [weak self] image, error in
      guard let self = self else { return }
      self.photoCaptureDelegate = nil
      if let error = error {
        completion(.failure(error))
        return
      }
      guard let cgImage = image else {
        completion(.failure(SessionError.noFrameAvailable))
        return
      }
      do {
        let map = try self.finalize(cgImage: cgImage, options: options, alreadyMirrored: false)
        completion(.success(map))
      } catch {
        completion(.failure(error))
      }
    }
    photoCaptureDelegate = delegate
    photoOutput.capturePhoto(with: settings, delegate: delegate)
  }

  private func encode(pixelBuffer: CVPixelBuffer, options: CaptureOptions) throws -> [String: Any] {
    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
    guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
      throw SessionError.encodingFailed
    }
    // プレビューでは前面カメラを鏡像表示しているため、
    // 保存時に設定へ従って元の向きへ戻す。
    let alreadyMirrored = lensDirection == .front
    return try finalize(cgImage: cgImage, options: options, alreadyMirrored: alreadyMirrored)
  }

  private func finalize(
    cgImage: CGImage,
    options: CaptureOptions,
    alreadyMirrored: Bool
  ) throws -> [String: Any] {
    var image = CIImage(cgImage: cgImage)

    let shouldMirror = lensDirection == .front && options.mirrorFrontCamera
    if alreadyMirrored != shouldMirror {
      image = image.transformed(
        by: CGAffineTransform(scaleX: -1, y: 1)
          .translatedBy(x: -image.extent.width, y: 0))
    }

    image = ImageProcessor.crop(image: image, to: options.aspectRatio)

    guard let processed = ciContext.createCGImage(image, from: image.extent) else {
      throw SessionError.encodingFailed
    }

    let capturedAt = Date()
    let metadata = ImageProcessor.metadata(
      capturedAt: capturedAt,
      model: DeviceInfo.modelIdentifier,
      location: options.includeLocation ? LocationProvider.shared.lastLocation : nil
    )

    guard
      let encoded = ImageProcessor.encode(
        image: processed,
        format: options.format,
        quality: options.jpegQuality,
        metadata: metadata
      )
    else {
      throw SessionError.encodingFailed
    }

    // HEIC 非対応端末では JPEG にフォールバックするため、実際の形式で命名する。
    let fileName = FileNameGenerator.make(at: capturedAt, format: encoded.format)
    let fileURL = try ImageProcessor.writeTemporaryFile(data: encoded.data, fileName: fileName)

    var map: [String: Any] = [
      "filePath": fileURL.path,
      "width": processed.width,
      "height": processed.height,
      "capturedAtEpochMs": Int(capturedAt.timeIntervalSince1970 * 1000),
      "fileName": fileName,
    ]

    if options.saveToGallery {
      let semaphore = DispatchSemaphore(value: 0)
      var identifier: String?
      var saveError: Error?
      PhotoLibrarySaver.save(fileURL: fileURL, albumName: options.albumName) { localId, error in
        identifier = localId
        saveError = error
        semaphore.signal()
      }
      semaphore.wait()
      if let saveError = saveError {
        throw saveError
      }
      map["galleryUri"] = identifier
    }

    return map
  }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension SilentCameraSession: AVCaptureVideoDataOutputSampleBufferDelegate {
  func captureOutput(
    _ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    bufferLock.lock()
    latestBuffer = pixelBuffer
    bufferLock.unlock()

    guard !isPreviewPaused else { return }
    textureRegistry?.textureFrameAvailable(textureId)
  }
}

// MARK: - FlutterTexture

extension SilentCameraSession: FlutterTexture {
  func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
    bufferLock.lock()
    defer { bufferLock.unlock() }
    guard let buffer = latestBuffer else { return nil }
    return Unmanaged.passRetained(buffer)
  }

  func onTextureUnregistered(_ texture: FlutterTexture) {
    bufferLock.lock()
    latestBuffer = nil
    bufferLock.unlock()
  }
}

extension FlashMode {
  var avFlashMode: AVCaptureDevice.FlashMode {
    switch self {
    case .on, .torch: return .on
    case .auto: return .auto
    case .off: return .off
    }
  }
}

/// `AVCapturePhotoOutput` の結果を受け取るデリゲート。
private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
  private let completion: (CGImage?, Error?) -> Void

  init(completion: @escaping (CGImage?, Error?) -> Void) {
    self.completion = completion
    super.init()
  }

  func photoOutput(
    _ output: AVCapturePhotoOutput,
    didFinishProcessingPhoto photo: AVCapturePhoto,
    error: Error?
  ) {
    if let error = error {
      completion(nil, error)
      return
    }
    completion(photo.cgImageRepresentation(), nil)
  }
}
