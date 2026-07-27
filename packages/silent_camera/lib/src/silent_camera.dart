import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'models.dart';

/// 無音キャプチャのネイティブ実装へのエントリポイント。
///
/// iOS は `AVCaptureVideoDataOutput`、Android は Camera2 の `ImageReader` から
/// 取得したフレームを静止画化することで、シャッター音を鳴らさずに撮影する。
class SilentCamera {
  SilentCamera._();

  /// アプリ全体で共有するインスタンス。
  static final SilentCamera instance = SilentCamera._();

  static const MethodChannel _defaultChannel =
      MethodChannel('dev.srzzumix.mumumu/silent_camera');

  MethodChannel _channel = _defaultChannel;

  /// テストからモックチャンネルを差し込むためのフック。
  @visibleForTesting
  set channel(MethodChannel channel) => _channel = channel;

  @visibleForTesting
  MethodChannel get channel => _channel;

  /// 利用可能なカメラの一覧を取得する。
  Future<List<SilentCameraDescription>> availableCameras() async {
    final result =
        await _channel.invokeMethod<List<Object?>>('availableCameras');
    return (result ?? const <Object?>[])
        .map(
          (Object? e) =>
              SilentCameraDescription.fromMap(e! as Map<Object?, Object?>),
        )
        .toList(growable: false);
  }

  /// 端末が無音撮影に対応しているかを問い合わせる。
  Future<SilenceCapability> silenceCapability() async {
    final result = await _channel
        .invokeMapMethod<Object?, Object?>('silenceCapability');
    return SilenceCapability.fromMap(result ?? const <Object?, Object?>{});
  }

  /// キャプチャセッションを開始する。
  Future<SilentCameraSession> initialize({
    required CameraLensDirection lensDirection,
    CaptureMode captureMode = CaptureMode.silent,
    AspectRatioPreset aspectRatio = AspectRatioPreset.ratio4x3,
  }) async {
    final result = await _channel.invokeMapMethod<Object?, Object?>(
      'initialize',
      <String, Object?>{
        'lensDirection': lensDirection.name,
        'captureMode': captureMode.name,
        'aspectRatio': aspectRatio.name,
      },
    );
    if (result == null) {
      throw StateError('Failed to initialize the silent camera session.');
    }
    return SilentCameraSession.fromMap(result);
  }

  /// セッションを破棄する。
  Future<void> dispose() => _channel.invokeMethod<void>('dispose');

  /// 現在のフレームから静止画を切り出し、フォトライブラリへ保存する。
  Future<CaptureResult> capture({
    PhotoFormat format = PhotoFormat.jpeg,
    int jpegQuality = 95,
    bool mirrorFrontCamera = false,
  }) async {
    final result = await _channel.invokeMapMethod<Object?, Object?>(
      'capture',
      <String, Object?>{
        'format': format.name,
        'jpegQuality': jpegQuality,
        'mirrorFrontCamera': mirrorFrontCamera,
      },
    );
    if (result == null) {
      throw StateError('Capture returned no result.');
    }
    return CaptureResult.fromMap(result);
  }

  /// フラッシュ動作を設定する。
  Future<void> setFlashMode(FlashMode mode) => _channel.invokeMethod<void>(
        'setFlashMode',
        <String, Object?>{'mode': mode.name},
      );

  /// ズーム倍率を設定する。
  Future<void> setZoomLevel(double zoom) => _channel.invokeMethod<void>(
        'setZoomLevel',
        <String, Object?>{'zoom': zoom},
      );

  /// プレビュー座標（0.0〜1.0）にフォーカスと露出を合わせる。
  Future<void> setFocusPoint(double x, double y) => _channel.invokeMethod<void>(
        'setFocusPoint',
        <String, Object?>{'x': x, 'y': y},
      );

  /// AE/AF ロックを切り替える。
  Future<void> setFocusExposureLocked({required bool locked}) =>
      _channel.invokeMethod<void>(
        'setFocusExposureLocked',
        <String, Object?>{'locked': locked},
      );

  /// 露出補正を設定する（EV 値）。
  Future<void> setExposureOffset(double offset) => _channel.invokeMethod<void>(
        'setExposureOffset',
        <String, Object?>{'offset': offset},
      );

  /// システムギャラリーで撮影結果を開く。
  Future<void> openInGallery(String uri) => _channel.invokeMethod<void>(
        'openInGallery',
        <String, Object?>{'uri': uri},
      );

  /// 撮影結果を削除する。
  Future<void> deleteCapture(String uri) => _channel.invokeMethod<void>(
        'deleteCapture',
        <String, Object?>{'uri': uri},
      );
}
