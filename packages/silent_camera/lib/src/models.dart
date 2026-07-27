import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';

/// カメラのレンズ方向。
enum CameraLensDirection { front, back, external }

/// フラッシュ動作。
enum FlashMode { off, on, auto, torch }

/// 撮影方式。
///
/// [silent] はビデオフレームからの切り出しによる無音撮影。
/// [photo] は OS の写真撮影 API を使うため、地域・端末によってはシャッター音が鳴る。
enum CaptureMode { silent, photo }

/// 保存する静止画のフォーマット。
enum PhotoFormat { jpeg, heic }

/// プレビュー / 保存時のアスペクト比。
enum AspectRatioPreset {
  ratio4x3(4 / 3),
  ratio16x9(16 / 9),
  ratio1x1(1);

  const AspectRatioPreset(this.value);

  /// 幅 / 高さ の比。
  final double value;
}

/// 利用可能なカメラの情報。
@immutable
class SilentCameraDescription {
  const SilentCameraDescription({
    required this.id,
    required this.lensDirection,
    required this.minZoom,
    required this.maxZoom,
    this.zoomPresets = const <double>[1],
  });

  factory SilentCameraDescription.fromMap(Map<Object?, Object?> map) {
    final zoomPresets = (map['zoomPresets'] as List<Object?>? ?? const [])
        .map((Object? e) => (e! as num).toDouble())
        .toList(growable: false);
    return SilentCameraDescription(
      id: map['id']! as String,
      lensDirection: _enumByName(
        CameraLensDirection.values,
        map['lensDirection'] as String?,
        CameraLensDirection.back,
      ),
      minZoom: (map['minZoom']! as num).toDouble(),
      maxZoom: (map['maxZoom']! as num).toDouble(),
      zoomPresets: zoomPresets.isEmpty ? const <double>[1] : zoomPresets,
    );
  }

  final String id;
  final CameraLensDirection lensDirection;
  final double minZoom;
  final double maxZoom;

  /// 端末のレンズ構成に応じた倍率ボタン用のプリセット（例: 0.5x / 1x / 2x）。
  final List<double> zoomPresets;

  @override
  bool operator ==(Object other) =>
      other is SilentCameraDescription &&
      other.id == id &&
      other.lensDirection == lensDirection &&
      other.minZoom == minZoom &&
      other.maxZoom == maxZoom &&
      listEquals(other.zoomPresets, zoomPresets);

  @override
  int get hashCode => Object.hash(id, lensDirection, minZoom, maxZoom);
}

/// 初期化済みのキャプチャセッション。
@immutable
class SilentCameraSession {
  const SilentCameraSession({
    required this.textureId,
    required this.previewSize,
    required this.description,
    required this.captureMode,
    required this.minExposureOffset,
    required this.maxExposureOffset,
  });

  factory SilentCameraSession.fromMap(Map<Object?, Object?> map) {
    return SilentCameraSession(
      textureId: (map['textureId']! as num).toInt(),
      previewSize: Size(
        (map['previewWidth']! as num).toDouble(),
        (map['previewHeight']! as num).toDouble(),
      ),
      description: SilentCameraDescription.fromMap(
        (map['camera']! as Map<Object?, Object?>),
      ),
      captureMode: _enumByName(
        CaptureMode.values,
        map['captureMode'] as String?,
        CaptureMode.silent,
      ),
      minExposureOffset: (map['minExposureOffset'] as num? ?? -2).toDouble(),
      maxExposureOffset: (map['maxExposureOffset'] as num? ?? 2).toDouble(),
    );
  }

  final int textureId;
  final Size previewSize;
  final SilentCameraDescription description;
  final CaptureMode captureMode;
  final double minExposureOffset;
  final double maxExposureOffset;
}

/// 撮影結果。
@immutable
class CaptureResult {
  const CaptureResult({
    required this.uri,
    required this.filePath,
    required this.width,
    required this.height,
    required this.capturedAt,
  });

  factory CaptureResult.fromMap(Map<Object?, Object?> map) {
    return CaptureResult(
      uri: map['uri']! as String,
      filePath: map['filePath'] as String?,
      width: (map['width']! as num).toInt(),
      height: (map['height']! as num).toInt(),
      capturedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['capturedAt']! as num).toInt(),
      ),
    );
  }

  /// システムギャラリー上の識別子（iOS: PHAsset localIdentifier / Android: content URI）。
  final String uri;

  /// サムネイル・ビューア表示用のキャッシュファイル。端末側で削除される場合がある。
  final String? filePath;
  final int width;
  final int height;
  final DateTime capturedAt;
}

/// 端末の無音撮影サポート状況。
@immutable
class SilenceCapability {
  const SilenceCapability({
    required this.isSilent,
    required this.deviceModel,
    this.reason,
  });

  factory SilenceCapability.fromMap(Map<Object?, Object?> map) {
    return SilenceCapability(
      isSilent: map['isSilent']! as bool,
      deviceModel: map['deviceModel'] as String? ?? '',
      reason: map['reason'] as String?,
    );
  }

  /// 無音での撮影が可能と判定されたか。
  final bool isSilent;
  final String deviceModel;

  /// 無音にできない場合の理由（アプリ内表示用のキー）。
  final String? reason;
}

T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }
  return fallback;
}
