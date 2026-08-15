import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';

/// カメラのレンズ方向。
enum CameraLensDirection {
  /// 前面（インカメラ）。
  front,

  /// 背面（アウトカメラ）。
  back,

  /// 外付けカメラ。
  external,
}

/// フラッシュの動作モード。
///
/// 仕様書 5.1「フラッシュ」に対応する。
enum FlashMode {
  /// 常に発光しない。
  off,

  /// 撮影時に必ず発光する。
  on,

  /// 明るさに応じて自動発光する。
  auto,

  /// 常時点灯（トーチ）。
  torch,
}

/// キャプチャ方式。
///
/// 仕様書 2.1 / 2.2 のとおり、無音撮影はビデオフレーム切り出しで実現する。
/// 端末が無音撮影に対応しない場合や、利用者が画質を優先した場合に
/// 写真モード（[photo]）へ切り替えられるようにする。
enum CaptureMode {
  /// ビデオフレームから静止画を切り出す無音方式。
  silentVideoFrame,

  /// OS の写真撮影 API を使う方式（端末によってはシャッター音が鳴る）。
  photo,
}

/// プレビュー／保存時のアスペクト比。
enum CaptureAspectRatio {
  /// 4:3。
  ratio4x3,

  /// 16:9。
  ratio16x9,

  /// 1:1。
  ratio1x1,
}

/// アスペクト比に関するユーティリティ。
extension CaptureAspectRatioX on CaptureAspectRatio {
  /// 横 / 縦 の比率値。
  double get value => switch (this) {
    CaptureAspectRatio.ratio4x3 => 4 / 3,
    CaptureAspectRatio.ratio16x9 => 16 / 9,
    CaptureAspectRatio.ratio1x1 => 1,
  };

  /// 表示用ラベル。
  String get label => switch (this) {
    CaptureAspectRatio.ratio4x3 => '4:3',
    CaptureAspectRatio.ratio16x9 => '16:9',
    CaptureAspectRatio.ratio1x1 => '1:1',
  };
}

/// 撮影解像度のプリセット。
enum CaptureResolution {
  /// 端末が対応する低解像度。
  low,

  /// 端末が対応する中解像度。
  medium,

  /// 端末が対応する高解像度。
  high,

  /// 端末が対応する最大解像度。
  max,
}

/// 保存画像のフォーマット。
enum CaptureFormat {
  /// JPEG。
  jpeg,

  /// HEIC。
  ///
  /// iOS のみ対応する（HEIC 非対応の端末では JPEG にフォールバックする）。
  /// Android は HEIC エンコードに非対応のため、常に JPEG で保存される。
  heic,
}

/// 利用可能なカメラの情報。
@immutable
class CameraDescription {
  /// 利用可能なカメラの情報を生成する。
  const CameraDescription({
    required this.id,
    required this.lensDirection,
    required this.sensorOrientation,
    this.minZoom = 1,
    this.maxZoom = 1,
    this.zoomPresets = const <double>[1],
    this.hasFlash = false,
  });

  /// プラットフォーム上のカメラ ID。
  final String id;

  /// レンズ方向。
  final CameraLensDirection lensDirection;

  /// センサーの実装上の向き（度）。
  final int sensorOrientation;

  /// 最小ズーム倍率。
  final double minZoom;

  /// 最大ズーム倍率。
  final double maxZoom;

  /// 倍率ボタンとして提示する代表的なズーム値（0.5x / 1x / 2x など）。
  final List<double> zoomPresets;

  /// フラッシュを備えるかどうか。
  final bool hasFlash;

  /// プラットフォームから受け取った [Map] を [CameraDescription] に変換する。
  factory CameraDescription.fromMap(Map<Object?, Object?> map) {
    return CameraDescription(
      id: map['id']! as String,
      lensDirection: _lensDirectionFromName(map['lensDirection'] as String?),
      sensorOrientation: (map['sensorOrientation'] as num?)?.toInt() ?? 0,
      minZoom: (map['minZoom'] as num?)?.toDouble() ?? 1,
      maxZoom: (map['maxZoom'] as num?)?.toDouble() ?? 1,
      zoomPresets:
          (map['zoomPresets'] as List<Object?>?)
              ?.map((Object? e) => (e! as num).toDouble())
              .toList(growable: false) ??
          const <double>[1],
      hasFlash: map['hasFlash'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CameraDescription &&
      other.id == id &&
      other.lensDirection == lensDirection;

  @override
  int get hashCode => Object.hash(id, lensDirection);

  @override
  String toString() => 'CameraDescription($id, $lensDirection)';
}

CameraLensDirection _lensDirectionFromName(String? name) {
  return CameraLensDirection.values.firstWhere(
    (CameraLensDirection e) => e.name == name,
    orElse: () => CameraLensDirection.back,
  );
}

/// カメラ初期化の結果。
@immutable
class CameraInitializationResult {
  /// カメラ初期化の結果を生成する。
  const CameraInitializationResult({
    required this.textureId,
    required this.previewSize,
    required this.description,
    required this.minExposureOffset,
    required this.maxExposureOffset,
    required this.exposureOffsetStep,
    this.previewQuarterTurns = 0,
    this.previewFlipHorizontally = false,
  });

  /// プレビュー描画に使うテクスチャ ID。
  final int textureId;

  /// プレビューのピクセルサイズ（回転適用後の表示サイズ）。
  final Size previewSize;

  /// テクスチャを表示するために必要な 90 度単位の回転数。
  ///
  /// iOS はネイティブ側で縦位置に補正するため 0、
  /// Android はセンサー実装の向きに応じた値を返す。
  final int previewQuarterTurns;

  /// 表示時に左右反転が必要かどうか（前面カメラの鏡像表示用）。
  final bool previewFlipHorizontally;

  /// 初期化されたカメラの情報。
  final CameraDescription description;

  /// 露出補正の下限（EV）。
  final double minExposureOffset;

  /// 露出補正の上限（EV）。
  final double maxExposureOffset;

  /// 露出補正の刻み幅（EV）。0 の場合は連続値。
  final double exposureOffsetStep;

  /// プラットフォームから受け取った [Map] を変換する。
  factory CameraInitializationResult.fromMap(Map<Object?, Object?> map) {
    return CameraInitializationResult(
      textureId: (map['textureId']! as num).toInt(),
      previewSize: Size(
        (map['previewWidth']! as num).toDouble(),
        (map['previewHeight']! as num).toDouble(),
      ),
      previewQuarterTurns: (map['previewQuarterTurns'] as num?)?.toInt() ?? 0,
      previewFlipHorizontally: map['previewFlipHorizontally'] as bool? ?? false,
      description: CameraDescription.fromMap(
        (map['description']! as Map<Object?, Object?>),
      ),
      minExposureOffset: (map['minExposureOffset'] as num?)?.toDouble() ?? 0,
      maxExposureOffset: (map['maxExposureOffset'] as num?)?.toDouble() ?? 0,
      exposureOffsetStep: (map['exposureOffsetStep'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// 撮影オプション。
@immutable
class CaptureOptions {
  /// 撮影オプションを生成する。
  const CaptureOptions({
    this.saveToGallery = true,
    this.jpegQuality = 95,
    this.format = CaptureFormat.jpeg,
    this.aspectRatio = CaptureAspectRatio.ratio4x3,
    this.mirrorFrontCamera = false,
    this.includeLocation = false,
    this.albumName = 'mumumu',
  });

  /// システムのフォトライブラリへ保存するかどうか。
  final bool saveToGallery;

  /// JPEG 品質（1-100）。
  final int jpegQuality;

  /// 保存フォーマット。
  final CaptureFormat format;

  /// 保存時のアスペクト比。
  final CaptureAspectRatio aspectRatio;

  /// 前面カメラの画像を左右反転して保存するかどうか。
  final bool mirrorFrontCamera;

  /// Exif に位置情報を付与するかどうか。
  final bool includeLocation;

  /// 保存先アルバム／フォルダ名。
  final String albumName;

  /// プラットフォームへ渡す [Map] に変換する。
  Map<String, Object?> toMap() => <String, Object?>{
    'saveToGallery': saveToGallery,
    'jpegQuality': jpegQuality,
    'format': format.name,
    'aspectRatio': aspectRatio.name,
    'mirrorFrontCamera': mirrorFrontCamera,
    'includeLocation': includeLocation,
    'albumName': albumName,
  };
}

/// 撮影結果。
@immutable
class CaptureResult {
  /// 撮影結果を生成する。
  const CaptureResult({
    required this.filePath,
    required this.width,
    required this.height,
    required this.capturedAt,
    this.galleryUri,
    this.fileName,
  });

  /// アプリのキャッシュ領域に書き出した一時ファイルのパス。
  ///
  /// 仕様書 7 のとおり、アプリ内には画像を保持しないため
  /// ビューア表示のための一時ファイルであり、次回起動時にクリアされる。
  final String filePath;

  /// 画像の幅（ピクセル）。
  final int width;

  /// 画像の高さ（ピクセル）。
  final int height;

  /// 撮影日時。
  final DateTime capturedAt;

  /// システムギャラリー上の URI（保存した場合のみ）。
  final String? galleryUri;

  /// 保存したファイル名。
  final String? fileName;

  /// プラットフォームから受け取った [Map] を変換する。
  factory CaptureResult.fromMap(Map<Object?, Object?> map) {
    return CaptureResult(
      filePath: map['filePath']! as String,
      width: (map['width']! as num).toInt(),
      height: (map['height']! as num).toInt(),
      capturedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['capturedAtEpochMs'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      ),
      galleryUri: map['galleryUri'] as String?,
      fileName: map['fileName'] as String?,
    );
  }
}

/// 端末の無音撮影対応状況。
///
/// 仕様書 2.3「端末互換性」に対応する。
@immutable
class SilenceCapability {
  /// 端末の無音撮影対応状況を生成する。
  const SilenceCapability({
    required this.isSilentCaptureSupported,
    required this.isShutterSoundEnforcedByOs,
    this.deviceModel = '',
    this.note = '',
  });

  /// ビデオフレーム切り出しによる無音撮影が利用できるかどうか。
  final bool isSilentCaptureSupported;

  /// OS がシャッター音を強制する地域／端末かどうか。
  final bool isShutterSoundEnforcedByOs;

  /// 端末モデル名。
  final String deviceModel;

  /// 補足説明。
  final String note;

  /// プラットフォームから受け取った [Map] を変換する。
  factory SilenceCapability.fromMap(Map<Object?, Object?> map) {
    return SilenceCapability(
      isSilentCaptureSupported:
          map['isSilentCaptureSupported'] as bool? ?? false,
      isShutterSoundEnforcedByOs:
          map['isShutterSoundEnforcedByOs'] as bool? ?? false,
      deviceModel: map['deviceModel'] as String? ?? '',
      note: map['note'] as String? ?? '',
    );
  }
}

/// プラグインが投げる例外。
class SilentCameraException implements Exception {
  /// プラグインが投げる例外を生成する。
  const SilentCameraException(this.code, this.message);

  /// エラーコード。
  final String code;

  /// エラーメッセージ。
  final String message;

  @override
  String toString() => 'SilentCameraException($code): $message';
}
