import AVFoundation
import Flutter
import UIKit

/// 無音キャプチャプラグインの iOS 実装。
///
/// 仕様書 2.1 のとおり、日本／韓国向け端末では `AVCapturePhotoOutput` の撮影音を
/// 抑止できないため、既定では `AVCaptureVideoDataOutput` のフレームから
/// 静止画を切り出す方式を用いる。
public class SilentCameraPlugin: NSObject, FlutterPlugin {
  private static let channelName = "dev.zumix.mumumu/silent_camera"

  private let textureRegistry: FlutterTextureRegistry
  private var session: SilentCameraSession?

  init(textureRegistry: FlutterTextureRegistry) {
    self.textureRegistry = textureRegistry
    super.init()
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    let instance = SilentCameraPlugin(textureRegistry: registrar.textures())
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]

    switch call.method {
    case "getSilenceCapability":
      result(SilenceCapability.current().toMap())

    case "availableCameras":
      result(CameraEnumerator.availableCameras().map { $0.toMap() })

    case "initialize":
      initialize(args: args, result: result)

    case "dispose":
      releaseSession()
      result(nil)

    case "pausePreview":
      session?.pausePreview()
      result(nil)

    case "resumePreview":
      session?.resumePreview()
      result(nil)

    case "capture":
      capture(args: args, result: result)

    case "setZoomLevel":
      guard let zoom = args["zoom"] as? Double else {
        result(Self.argumentError("zoom"))
        return
      }
      run(result) { try $0.setZoomLevel(CGFloat(zoom)) }

    case "setFocusAndExposurePoint":
      guard let x = args["x"] as? Double, let y = args["y"] as? Double else {
        result(Self.argumentError("x/y"))
        return
      }
      run(result) { try $0.setFocusAndExposurePoint(CGPoint(x: x, y: y)) }

    case "setFocusAndExposureLocked":
      let locked = args["locked"] as? Bool ?? false
      run(result) { try $0.setFocusAndExposureLocked(locked) }

    case "setExposureOffset":
      guard let offset = args["offset"] as? Double else {
        result(Self.argumentError("offset"))
        return
      }
      run(result) { try $0.setExposureOffset(Float(offset)) }

    case "setFlashMode":
      let mode = FlashMode(rawValue: args["mode"] as? String ?? "off") ?? .off
      run(result) { try $0.setFlashMode(mode) }

    case "openInGallery":
      guard let uri = args["uri"] as? String else {
        result(Self.argumentError("uri"))
        return
      }
      PhotoLibrarySaver.openInPhotos(localIdentifier: uri)
      result(nil)

    case "deleteFromGallery":
      guard let uri = args["uri"] as? String else {
        result(Self.argumentError("uri"))
        return
      }
      PhotoLibrarySaver.delete(localIdentifier: uri) { deleted, error in
        DispatchQueue.main.async {
          if let error = error {
            result(
              FlutterError(
                code: "delete_failed", message: error.localizedDescription, details: nil))
          } else {
            result(deleted)
          }
        }
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Private

  private func initialize(args: [String: Any], result: @escaping FlutterResult) {
    let lensDirection = LensDirection(rawValue: args["lensDirection"] as? String ?? "back") ?? .back
    let resolution = CaptureResolution(rawValue: args["resolution"] as? String ?? "max") ?? .max
    let captureMode =
      CaptureMode(rawValue: args["captureMode"] as? String ?? "silentVideoFrame")
      ?? .silentVideoFrame

    releaseSession()

    let newSession = SilentCameraSession(
      lensDirection: lensDirection,
      resolution: resolution,
      captureMode: captureMode
    )

    do {
      try newSession.configure()
    } catch {
      result(
        FlutterError(
          code: "initialize_failed", message: error.localizedDescription, details: nil))
      return
    }

    let textureId = textureRegistry.register(newSession)
    newSession.attach(registry: textureRegistry, textureId: textureId)
    newSession.start()
    session = newSession

    result(newSession.initializationMap())
  }

  private func capture(args: [String: Any], result: @escaping FlutterResult) {
    guard let session = session else {
      result(
        FlutterError(code: "not_initialized", message: "カメラが初期化されていません。", details: nil))
      return
    }

    let options = CaptureOptions(map: args)
    session.capture(options: options) { captureResult in
      DispatchQueue.main.async {
        switch captureResult {
        case .success(let map):
          result(map)
        case .failure(let error):
          result(
            FlutterError(
              code: "capture_failed", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  private func releaseSession() {
    guard let current = session else { return }
    current.stop()
    textureRegistry.unregisterTexture(current.textureId)
    session = nil
  }

  private func run(_ result: @escaping FlutterResult, _ body: (SilentCameraSession) throws -> Void) {
    guard let session = session else {
      result(
        FlutterError(code: "not_initialized", message: "カメラが初期化されていません。", details: nil))
      return
    }
    do {
      try body(session)
      result(nil)
    } catch {
      result(
        FlutterError(code: "camera_error", message: error.localizedDescription, details: nil))
    }
  }

  private static func argumentError(_ name: String) -> FlutterError {
    FlutterError(code: "invalid_argument", message: "\(name) が指定されていません。", details: nil)
  }
}
