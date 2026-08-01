import AVFoundation
import Foundation

/// Dart 側 `CameraLensDirection` に対応する。
enum LensDirection: String {
  case front
  case back
  case external

  var avPosition: AVCaptureDevice.Position {
    switch self {
    case .front: return .front
    case .back: return .back
    case .external: return .unspecified
    }
  }

  static func from(_ position: AVCaptureDevice.Position) -> LensDirection {
    switch position {
    case .front: return .front
    case .back: return .back
    default: return .external
    }
  }
}

/// Dart 側 `FlashMode` に対応する。
enum FlashMode: String {
  case off
  case on
  case auto
  case torch
}

/// Dart 側 `CaptureMode` に対応する。
enum CaptureMode: String {
  case silentVideoFrame
  case photo
}

/// Dart 側 `CaptureResolution` に対応する。
enum CaptureResolution: String {
  case low
  case medium
  case high
  case max

  /// ビデオフレーム方式で使用するセッションプリセット。
  ///
  /// 仕様書 10 の対策のとおり、既定では端末が対応する最大解像度を選ぶ。
  var sessionPreset: AVCaptureSession.Preset {
    switch self {
    case .low: return .vga640x480
    case .medium: return .hd1280x720
    case .high: return .hd1920x1080
    case .max: return .hd4K3840x2160
    }
  }

  /// 指定プリセットが使えない場合のフォールバック順。
  var fallbackPresets: [AVCaptureSession.Preset] {
    switch self {
    case .low: return [.vga640x480, .hd1280x720, .high]
    case .medium: return [.hd1280x720, .hd1920x1080, .high]
    case .high: return [.hd1920x1080, .hd1280x720, .high]
    case .max: return [.hd4K3840x2160, .hd1920x1080, .hd1280x720, .high]
    }
  }
}

/// Dart 側 `CaptureAspectRatio` に対応する。
enum CaptureAspectRatio: String {
  case ratio4x3
  case ratio16x9
  case ratio1x1

  /// 横 / 縦 の比率。縦位置で使うため逆数で扱う点に注意。
  var value: CGFloat {
    switch self {
    case .ratio4x3: return 4.0 / 3.0
    case .ratio16x9: return 16.0 / 9.0
    case .ratio1x1: return 1.0
    }
  }
}

/// Dart 側 `CaptureFormat` に対応する。
enum CaptureFormat: String {
  case jpeg
  case heic
}

/// Dart 側 `CaptureOptions` に対応する。
struct CaptureOptions {
  let saveToGallery: Bool
  let jpegQuality: CGFloat
  let format: CaptureFormat
  let aspectRatio: CaptureAspectRatio
  let mirrorFrontCamera: Bool
  let includeLocation: Bool
  let albumName: String

  init(map: [String: Any]) {
    saveToGallery = map["saveToGallery"] as? Bool ?? true
    let quality = map["jpegQuality"] as? Int ?? 95
    jpegQuality = CGFloat(min(100, Swift.max(1, quality))) / 100.0
    format = CaptureFormat(rawValue: map["format"] as? String ?? "jpeg") ?? .jpeg
    aspectRatio =
      CaptureAspectRatio(rawValue: map["aspectRatio"] as? String ?? "ratio4x3") ?? .ratio4x3
    mirrorFrontCamera = map["mirrorFrontCamera"] as? Bool ?? false
    includeLocation = map["includeLocation"] as? Bool ?? false
    albumName = map["albumName"] as? String ?? "mumumu"
  }
}

/// Dart 側 `CameraDescription` に対応する。
struct CameraDescriptionData {
  let id: String
  let lensDirection: LensDirection
  let sensorOrientation: Int
  let minZoom: Double
  let maxZoom: Double
  let zoomPresets: [Double]
  let hasFlash: Bool

  func toMap() -> [String: Any] {
    [
      "id": id,
      "lensDirection": lensDirection.rawValue,
      "sensorOrientation": sensorOrientation,
      "minZoom": minZoom,
      "maxZoom": maxZoom,
      "zoomPresets": zoomPresets,
      "hasFlash": hasFlash,
    ]
  }
}

/// 端末の無音撮影対応状況。仕様書 2.3 に対応する。
struct SilenceCapability {
  let isSilentCaptureSupported: Bool
  let isShutterSoundEnforcedByOs: Bool
  let deviceModel: String
  let note: String

  /// 実行中の端末の状況を返す。
  ///
  /// 日本・韓国向けに販売された端末では、写真モードのシャッター音を
  /// アプリから抑止できない。ビデオフレーム方式は地域を問わず無音で動作する。
  static func current() -> SilenceCapability {
    let region = Locale.current.regionCode ?? ""
    let enforced = ["JP", "KR"].contains(region)
    return SilenceCapability(
      isSilentCaptureSupported: true,
      isShutterSoundEnforcedByOs: enforced,
      deviceModel: DeviceInfo.modelIdentifier,
      note: enforced
        ? "この端末では写真モードのシャッター音を抑止できません。静音撮影モードをご利用ください。"
        : ""
    )
  }

  func toMap() -> [String: Any] {
    [
      "isSilentCaptureSupported": isSilentCaptureSupported,
      "isShutterSoundEnforcedByOs": isShutterSoundEnforcedByOs,
      "deviceModel": deviceModel,
      "note": note,
    ]
  }
}

/// 端末情報のユーティリティ。
enum DeviceInfo {
  static var modelIdentifier: String {
    var systemInfo = utsname()
    uname(&systemInfo)
    let mirror = Mirror(reflecting: systemInfo.machine)
    return mirror.children.reduce(into: "") { identifier, element in
      guard let value = element.value as? Int8, value != 0 else { return }
      identifier += String(UnicodeScalar(UInt8(value)))
    }
  }
}

/// 利用可能なカメラを列挙する。
enum CameraEnumerator {
  static let deviceTypes: [AVCaptureDevice.DeviceType] = {
    var types: [AVCaptureDevice.DeviceType] = [
      .builtInTripleCamera,
      .builtInDualWideCamera,
      .builtInDualCamera,
      .builtInWideAngleCamera,
      .builtInUltraWideCamera,
      .builtInTelephotoCamera,
    ]
    return types
  }()

  static func devices() -> [AVCaptureDevice] {
    AVCaptureDevice.DiscoverySession(
      deviceTypes: deviceTypes,
      mediaType: .video,
      position: .unspecified
    ).devices
  }

  /// 指定した向きで最も高機能なカメラを選ぶ。
  static func bestDevice(for direction: LensDirection) -> AVCaptureDevice? {
    let position = direction.avPosition
    let candidates = devices().filter { position == .unspecified || $0.position == position }
    for type in deviceTypes {
      if let device = candidates.first(where: { $0.deviceType == type }) {
        return device
      }
    }
    return candidates.first
  }

  static func availableCameras() -> [CameraDescriptionData] {
    devices().map { description(of: $0) }
  }

  static func description(of device: AVCaptureDevice) -> CameraDescriptionData {
    CameraDescriptionData(
      id: device.uniqueID,
      lensDirection: LensDirection.from(device.position),
      sensorOrientation: 90,
      minZoom: Double(device.minAvailableVideoZoomFactor),
      maxZoom: Double(min(device.maxAvailableVideoZoomFactor, 10.0)),
      zoomPresets: zoomPresets(of: device),
      hasFlash: device.hasTorch || device.hasFlash
    )
  }

  /// 倍率ボタン（0.5x / 1x / 2x など）に使う代表的なズーム値を求める。
  ///
  /// 仮想デバイス（Dual / Triple）ではレンズ切替倍率を基準に構成する。
  private static func zoomPresets(of device: AVCaptureDevice) -> [Double] {
    let maxZoom = Double(min(device.maxAvailableVideoZoomFactor, 10.0))
    let switchOverFactors = device.virtualDeviceSwitchOverVideoZoomFactors.map { $0.doubleValue }

    // 超広角を含む構成では 1.0 が広角に相当するよう 0.5x を提示する。
    var presets: [Double] = [1.0]
    if device.deviceType == .builtInTripleCamera || device.deviceType == .builtInDualWideCamera {
      presets.insert(Double(device.minAvailableVideoZoomFactor), at: 0)
    }
    presets.append(contentsOf: switchOverFactors)
    if !presets.contains(where: { $0 >= 2.0 }) && maxZoom >= 2.0 {
      presets.append(2.0)
    }

    let unique = Array(Set(presets.map { ($0 * 10).rounded() / 10 })).sorted()
    return unique.filter { $0 >= Double(device.minAvailableVideoZoomFactor) && $0 <= maxZoom }
  }
}
