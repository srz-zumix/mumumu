import Flutter
import UIKit

/// AVFoundation のビデオフレームから静止画を生成し、
/// シャッター音を鳴らさずに撮影する mumumu 専用プラグイン。
public class SilentCameraPlugin: NSObject, FlutterPlugin {

    private static let channelName = "dev.srzzumix.mumumu/silent_camera"

    private let registry: FlutterTextureRegistry
    private var session: CameraSession?
    private let library = PhotoLibrarySaver()

    init(registry: FlutterTextureRegistry) {
        self.registry = registry
        super.init()
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger()
        )
        let instance = SilentCameraPlugin(registry: registrar.textures())
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "availableCameras":
            result(CameraSession.availableCameras())
        case "silenceCapability":
            result(SilenceCapability.describe())
        case "initialize":
            initialize(arguments: arguments, result: result)
        case "dispose":
            closeSession()
            result(nil)
        case "capture":
            capture(arguments: arguments, result: result)
        case "setFlashMode":
            withSession(result) { $0.setFlashMode(arguments["mode"] as? String ?? "off") }
        case "setZoomLevel":
            withSession(result) { $0.setZoomLevel(arguments["zoom"] as? Double ?? 1) }
        case "setFocusPoint":
            withSession(result) {
                $0.setFocusPoint(
                    x: arguments["x"] as? Double ?? 0.5,
                    y: arguments["y"] as? Double ?? 0.5
                )
            }
        case "setFocusExposureLocked":
            withSession(result) {
                $0.setFocusExposureLocked(arguments["locked"] as? Bool ?? false)
            }
        case "setExposureOffset":
            withSession(result) {
                $0.setExposureOffset(arguments["offset"] as? Double ?? 0)
            }
        case "openInGallery":
            guard let uri = arguments["uri"] as? String else {
                result(argumentError("uri"))
                return
            }
            library.openInGallery(identifier: uri)
            result(nil)
        case "deleteCapture":
            guard let uri = arguments["uri"] as? String else {
                result(argumentError("uri"))
                return
            }
            library.delete(identifier: uri) { error in
                if let error = error {
                    result(FlutterError(code: "delete_failed", message: error, details: nil))
                } else {
                    result(nil)
                }
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
        closeSession()
    }

    private func initialize(arguments: [String: Any], result: @escaping FlutterResult) {
        closeSession()
        let newSession = CameraSession(registry: registry)
        session = newSession
        newSession.start(
            lensDirection: arguments["lensDirection"] as? String ?? "back",
            captureMode: arguments["captureMode"] as? String ?? "silent",
            aspectRatio: arguments["aspectRatio"] as? String ?? "ratio4x3"
        ) { [weak self] outcome in
            switch outcome {
            case .success(let info):
                result(info)
            case .failure(let error):
                self?.closeSession()
                result(
                    FlutterError(
                        code: "initialize_failed",
                        message: error.localizedDescription,
                        details: nil
                    )
                )
            }
        }
    }

    private func capture(arguments: [String: Any], result: @escaping FlutterResult) {
        guard let session = session else {
            result(FlutterError(code: "no_session", message: "Camera session is not initialized.", details: nil))
            return
        }
        session.capture(
            format: arguments["format"] as? String ?? "jpeg",
            quality: arguments["jpegQuality"] as? Int ?? 95,
            mirrorFrontCamera: arguments["mirrorFrontCamera"] as? Bool ?? false,
            library: library
        ) { outcome in
            switch outcome {
            case .success(let info):
                result(info)
            case .failure(let error):
                result(
                    FlutterError(
                        code: "capture_failed",
                        message: error.localizedDescription,
                        details: nil
                    )
                )
            }
        }
    }

    private func withSession(_ result: @escaping FlutterResult, _ block: (CameraSession) -> Void) {
        guard let session = session else {
            result(FlutterError(code: "no_session", message: "Camera session is not initialized.", details: nil))
            return
        }
        block(session)
        result(nil)
    }

    private func argumentError(_ name: String) -> FlutterError {
        FlutterError(code: "invalid_argument", message: "\(name) is required", details: nil)
    }

    private func closeSession() {
        session?.stop()
        session = nil
    }
}
