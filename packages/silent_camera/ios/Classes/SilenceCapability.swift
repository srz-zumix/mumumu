import Foundation
import UIKit

/// 端末が無音撮影に対応しているかを判定する。
///
/// 日本・韓国向けに販売された端末では `AVCapturePhotoOutput` による撮影時に
/// OS がシャッター音を鳴らす。フレーム切り出し方式ではこの制約を受けないが、
/// 写真モードでは音が鳴る点をアプリ内で明示する。
enum SilenceCapability {

    private static let forcedShutterSoundRegions: Set<String> = ["JP", "KR"]

    static func describe() -> [String: Any] {
        let region = Locale.current.region?.identifier ?? ""
        let forced = forcedShutterSoundRegions.contains(region)
        var info: [String: Any] = [
            "isSilent": true,
            "deviceModel": UIDevice.current.model
        ]
        if forced {
            info["reason"] =
                "この地域向けの端末では写真モードのシャッター音が OS により強制されます。"
                + "無音で撮影するには「無音（フレーム切り出し）」方式をご利用ください。"
        }
        return info
    }
}
