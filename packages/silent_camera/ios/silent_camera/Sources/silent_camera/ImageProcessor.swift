import CoreImage
import CoreLocation
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// 画像の切り出し・メタデータ付与・書き出しを行うユーティリティ。
enum ImageProcessor {
  /// 縦位置基準で指定アスペクト比に中央クロップする。
  static func crop(image: CIImage, to aspectRatio: CaptureAspectRatio) -> CIImage {
    let extent = image.extent
    guard extent.width > 0, extent.height > 0 else { return image }

    let isPortrait = extent.height >= extent.width
    // `CaptureAspectRatio` は横基準の比率なので、縦位置では逆数を使う。
    let targetRatio = isPortrait ? 1.0 / aspectRatio.value : aspectRatio.value
    let currentRatio = extent.width / extent.height
    if abs(currentRatio - targetRatio) < 0.001 {
      return image
    }

    var cropWidth = extent.width
    var cropHeight = extent.height
    if currentRatio > targetRatio {
      cropWidth = extent.height * targetRatio
    } else {
      cropHeight = extent.width / targetRatio
    }

    let cropRect = CGRect(
      x: extent.origin.x + (extent.width - cropWidth) / 2.0,
      y: extent.origin.y + (extent.height - cropHeight) / 2.0,
      width: cropWidth,
      height: cropHeight
    )
    return image.cropped(to: cropRect)
  }

  /// Exif / TIFF / GPS メタデータを構築する。仕様書 7 に対応する。
  static func metadata(
    capturedAt: Date,
    model: String,
    location: CLLocation?
  ) -> [String: Any] {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
    let timestamp = formatter.string(from: capturedAt)

    var metadata: [String: Any] = [
      kCGImagePropertyOrientation as String: 1,
      kCGImagePropertyExifDictionary as String: [
        kCGImagePropertyExifDateTimeOriginal as String: timestamp,
        kCGImagePropertyExifDateTimeDigitized as String: timestamp,
      ],
      kCGImagePropertyTIFFDictionary as String: [
        kCGImagePropertyTIFFMake as String: "Apple",
        kCGImagePropertyTIFFModel as String: model,
        kCGImagePropertyTIFFDateTime as String: timestamp,
        kCGImagePropertyTIFFSoftware as String: "mumumu",
      ],
    ]

    if let location = location {
      let gpsFormatter = DateFormatter()
      gpsFormatter.locale = Locale(identifier: "en_US_POSIX")
      gpsFormatter.dateFormat = "HH:mm:ss"
      gpsFormatter.timeZone = TimeZone(identifier: "UTC")
      let dateFormatter = DateFormatter()
      dateFormatter.locale = Locale(identifier: "en_US_POSIX")
      dateFormatter.dateFormat = "yyyy:MM:dd"
      dateFormatter.timeZone = TimeZone(identifier: "UTC")

      metadata[kCGImagePropertyGPSDictionary as String] = [
        kCGImagePropertyGPSLatitude as String: abs(location.coordinate.latitude),
        kCGImagePropertyGPSLatitudeRef as String: location.coordinate.latitude >= 0 ? "N" : "S",
        kCGImagePropertyGPSLongitude as String: abs(location.coordinate.longitude),
        kCGImagePropertyGPSLongitudeRef as String: location.coordinate.longitude >= 0 ? "E" : "W",
        kCGImagePropertyGPSAltitude as String: abs(location.altitude),
        kCGImagePropertyGPSAltitudeRef as String: location.altitude >= 0 ? 0 : 1,
        kCGImagePropertyGPSTimeStamp as String: gpsFormatter.string(from: location.timestamp),
        kCGImagePropertyGPSDateStamp as String: dateFormatter.string(from: location.timestamp),
      ]
    }

    return metadata
  }

  /// 指定フォーマットで画像データを書き出す。
  ///
  /// HEIC 非対応端末では JPEG にフォールバックするため、
  /// 実際にエンコードに用いた [CaptureFormat] を併せて返す。
  static func encode(
    image: CGImage,
    format: CaptureFormat,
    quality: CGFloat,
    metadata: [String: Any]
  ) -> (data: Data, format: CaptureFormat)? {
    if format == .heic,
      let data = encode(image: image, type: UTType.heic, quality: quality, metadata: metadata)
    {
      return (data, .heic)
    }
    guard let data = encode(image: image, type: UTType.jpeg, quality: quality, metadata: metadata)
    else {
      return nil
    }
    return (data, .jpeg)
  }

  private static func encode(
    image: CGImage,
    type: UTType,
    quality: CGFloat,
    metadata: [String: Any]
  ) -> Data? {
    let data = NSMutableData()
    guard
      let destination = CGImageDestinationCreateWithData(
        data as CFMutableData, type.identifier as CFString, 1, nil)
    else {
      return nil
    }

    var properties = metadata
    properties[kCGImageDestinationLossyCompressionQuality as String] = quality
    CGImageDestinationAddImage(destination, image, properties as CFDictionary)

    guard CGImageDestinationFinalize(destination) else { return nil }
    return data as Data
  }

  /// 一時ディレクトリへ書き出す。
  ///
  /// 仕様書 7 のとおりアプリ内に画像を保持しないため、
  /// ビューア表示用のキャッシュとしてのみ利用する。
  static func writeTemporaryFile(data: Data, fileName: String) throws -> URL {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("mumumu_captures", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent(fileName)
    try data.write(to: url, options: .atomic)
    return url
  }
}

/// 仕様書 7 の命名規則 `IMG_yyyyMMdd_HHmmss[_n]` に従うファイル名を生成する。
enum FileNameGenerator {
  private static var lastBaseName = ""
  private static var sequence = 0
  private static let lock = NSLock()

  static func make(at date: Date, format: CaptureFormat) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyyMMdd_HHmmss"
    let base = "IMG_\(formatter.string(from: date))"

    lock.lock()
    defer { lock.unlock() }
    if base == lastBaseName {
      sequence += 1
    } else {
      lastBaseName = base
      sequence = 0
    }
    let suffix = sequence == 0 ? "" : "_\(sequence)"
    let ext = format == .heic ? "heic" : "jpg"
    return "\(base)\(suffix).\(ext)"
  }
}

/// Exif への位置情報付与に用いる現在地を保持する。
///
/// 仕様書 5.2 のとおり、設定が有効な場合のみ利用する。
final class LocationProvider: NSObject, CLLocationManagerDelegate {
  static let shared = LocationProvider()

  private let manager = CLLocationManager()
  private var isTracking = false

  private override init() {
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
  }

  /// 直近に取得できた位置。権限がない場合は nil。
  var lastLocation: CLLocation? {
    guard isAuthorized else { return nil }
    startIfNeeded()
    return manager.location
  }

  private var isAuthorized: Bool {
    switch manager.authorizationStatus {
    case .authorizedAlways, .authorizedWhenInUse: return true
    default: return false
    }
  }

  private func startIfNeeded() {
    guard !isTracking else { return }
    isTracking = true
    manager.startUpdatingLocation()
  }

  func stop() {
    isTracking = false
    manager.stopUpdatingLocation()
  }
}
