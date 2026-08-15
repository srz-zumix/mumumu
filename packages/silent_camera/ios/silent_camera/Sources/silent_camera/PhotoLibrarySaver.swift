import Foundation
import Photos
import UIKit

/// フォトライブラリへの保存・削除・表示を担当する。
///
/// 仕様書 7 のとおり `mumumu` アルバムへ整理して保存する。
enum PhotoLibrarySaver {
  enum SaveError: LocalizedError {
    case permissionDenied

    var errorDescription: String? {
      switch self {
      case .permissionDenied:
        return "写真ライブラリへのアクセスが許可されていません。"
      }
    }
  }

  /// 画像ファイルをフォトライブラリへ保存する。
  ///
  /// - Returns: 保存したアセットのローカル識別子。
  static func save(
    fileURL: URL,
    albumName: String,
    completion: @escaping (String?, Error?) -> Void
  ) {
    requestAuthorization { authorized in
      guard authorized else {
        completion(nil, SaveError.permissionDenied)
        return
      }

      var placeholder: PHObjectPlaceholder?
      PHPhotoLibrary.shared().performChanges {
        guard
          let request = PHAssetCreationRequest.creationRequestForAssetFromImage(atFileURL: fileURL)
        else {
          return
        }
        placeholder = request.placeholderForCreatedAsset

        if let album = fetchOrCreateAlbumRequest(named: albumName),
          let assetPlaceholder = placeholder
        {
          album.addAssets([assetPlaceholder] as NSArray)
        }
      } completionHandler: { success, error in
        if let error = error {
          completion(nil, error)
        } else if success {
          completion(placeholder?.localIdentifier, nil)
        } else {
          completion(nil, nil)
        }
      }
    }
  }

  /// 指定したアセットを削除する。
  static func delete(localIdentifier: String, completion: @escaping (Bool, Error?) -> Void) {
    let assets = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
    guard assets.count > 0 else {
      completion(false, nil)
      return
    }
    PHPhotoLibrary.shared().performChanges {
      PHAssetChangeRequest.deleteAssets(assets)
    } completionHandler: { success, error in
      completion(success, error)
    }
  }

  /// 写真アプリを開く。
  ///
  /// iOS には特定アセットを Photos アプリで直接開く公開 API がないため、
  /// アプリ自体を前面に出すのみで `localIdentifier` のアセットは指定できない。
  /// 引数はプラットフォーム間で API を揃えるために残している。
  static func openInPhotos(localIdentifier _: String) {
    // `photos-redirect://` は写真アプリを前面に出すためのスキーム。
    guard let url = URL(string: "photos-redirect://") else { return }
    DispatchQueue.main.async {
      if UIApplication.shared.canOpenURL(url) {
        UIApplication.shared.open(url)
      }
    }
  }

  // MARK: - Private

  private static func requestAuthorization(_ completion: @escaping (Bool) -> Void) {
    let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
    switch status {
    case .authorized, .limited:
      completion(true)
    case .notDetermined:
      PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
        completion(newStatus == .authorized || newStatus == .limited)
      }
    default:
      completion(false)
    }
  }

  /// アルバムを取得、存在しなければ作成する変更リクエストを返す。
  ///
  /// `performChanges` ブロック内から呼び出すこと。
  private static func fetchOrCreateAlbumRequest(named name: String)
    -> PHAssetCollectionChangeRequest?
  {
    let options = PHFetchOptions()
    options.predicate = NSPredicate(format: "title = %@", name)
    let collections = PHAssetCollection.fetchAssetCollections(
      with: .album, subtype: .albumRegular, options: options)

    if let existing = collections.firstObject {
      return PHAssetCollectionChangeRequest(for: existing)
    }
    return PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
  }
}
