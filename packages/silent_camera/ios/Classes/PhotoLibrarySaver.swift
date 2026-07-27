import Foundation
import Photos
import UIKit

/// 撮影結果を `mumumu` アルバムへ保存するヘルパー。
final class PhotoLibrarySaver {

    private static let albumName = "mumumu"

    /// 画像データをフォトライブラリへ保存し、Dart へ返す情報を組み立てる。
    func save(
        data: Data,
        width: Int,
        height: Int,
        isHeic: Bool,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        let capturedAt = Date()
        var localIdentifier: String?
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: data, options: nil)
            request.creationDate = capturedAt
            localIdentifier = request.placeholderForCreatedAsset?.localIdentifier
            if let album = self.fetchOrCreateAlbumChangeRequest(),
               let placeholder = request.placeholderForCreatedAsset {
                album.addAssets([placeholder] as NSArray)
            }
        }, completionHandler: { success, error in
            guard success, let identifier = localIdentifier else {
                let message = error?.localizedDescription ?? "フォトライブラリへ保存できませんでした。"
                DispatchQueue.main.async {
                    completion(.failure(SilentCameraError.saveFailed(message)))
                }
                return
            }
            do {
                let path = try self.writeCacheCopy(
                    data: data,
                    capturedAt: capturedAt,
                    isHeic: isHeic
                )
                DispatchQueue.main.async {
                    completion(
                        .success([
                            "uri": identifier,
                            "filePath": path,
                            "width": width,
                            "height": height,
                            "capturedAt": Int(capturedAt.timeIntervalSince1970 * 1000)
                        ])
                    )
                }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        })
    }

    /// システムの写真アプリを開く。
    ///
    /// iOS には特定のアセットを直接開く公開 API がないため、写真アプリを起動する。
    /// `photos-redirect://` は写真アプリの標準スキームで、開けない場合は何もしない。
    func openInGallery(identifier: String) {
        let exists = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
            .firstObject != nil
        guard exists, let url = URL(string: "photos-redirect://") else { return }
        DispatchQueue.main.async {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }

    /// 対象アセットを削除する。
    func delete(identifier: String, completion: @escaping (String?) -> Void) {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard assets.count > 0 else {
            completion("削除対象が見つかりませんでした。")
            return
        }
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(assets)
        }, completionHandler: { success, error in
            DispatchQueue.main.async {
                completion(success ? nil : (error?.localizedDescription ?? "削除できませんでした。"))
            }
        })
    }

    private func fetchOrCreateAlbumChangeRequest() -> PHAssetCollectionChangeRequest? {
        if let album = fetchAlbum() {
            return PHAssetCollectionChangeRequest(for: album)
        }
        return PHAssetCollectionChangeRequest.creationRequestForAssetCollection(
            withTitle: Self.albumName
        )
    }

    private func fetchAlbum() -> PHAssetCollection? {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "title = %@", Self.albumName)
        return PHAssetCollection.fetchAssetCollections(
            with: .album,
            subtype: .albumRegular,
            options: options
        ).firstObject
    }

    /// ビューア表示用のキャッシュを最新 1 件だけ残す。
    private func writeCacheCopy(data: Data, capturedAt: Date, isHeic: Bool) throws -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory.appendingPathComponent("captures")
        if fileManager.fileExists(atPath: directory.path) {
            try? fileManager.removeItem(at: directory)
        }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = "IMG_\(formatter.string(from: capturedAt)).\(isHeic ? "heic" : "jpg")"
        let url = directory.appendingPathComponent(name)
        try data.write(to: url)
        return url.path
    }
}
