import 'dart:ui' show Offset;

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'models.dart';
import 'silent_camera_method_channel.dart';

/// 無音カメラのプラットフォーム実装が満たすインターフェース。
abstract class SilentCameraPlatform extends PlatformInterface {
  /// 無音カメラのプラットフォーム実装を生成する。
  SilentCameraPlatform() : super(token: _token);

  static final Object _token = Object();

  static SilentCameraPlatform _instance = MethodChannelSilentCamera();

  /// 現在のプラットフォーム実装。
  static SilentCameraPlatform get instance => _instance;

  /// プラットフォーム実装を差し替える（テスト用）。
  static set instance(SilentCameraPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// 端末の無音撮影対応状況を取得する。
  Future<SilenceCapability> getSilenceCapability() {
    throw UnimplementedError('getSilenceCapability() は未実装です。');
  }

  /// 利用可能なカメラの一覧を取得する。
  Future<List<CameraDescription>> availableCameras() {
    throw UnimplementedError('availableCameras() は未実装です。');
  }

  /// カメラを初期化する。
  Future<CameraInitializationResult> initialize({
    required CameraLensDirection lensDirection,
    required CaptureResolution resolution,
    required CaptureMode captureMode,
  }) {
    throw UnimplementedError('initialize() は未実装です。');
  }

  /// カメラを解放する。
  Future<void> dispose() {
    throw UnimplementedError('dispose() は未実装です。');
  }

  /// プレビューを一時停止する。
  Future<void> pausePreview() {
    throw UnimplementedError('pausePreview() は未実装です。');
  }

  /// プレビューを再開する。
  Future<void> resumePreview() {
    throw UnimplementedError('resumePreview() は未実装です。');
  }

  /// 静止画を撮影する。
  Future<CaptureResult> capture(CaptureOptions options) {
    throw UnimplementedError('capture() は未実装です。');
  }

  /// ズーム倍率を設定する。
  Future<void> setZoomLevel(double zoom) {
    throw UnimplementedError('setZoomLevel() は未実装です。');
  }

  /// フォーカスと露出の測定点を設定する（プレビュー内の 0.0-1.0 座標）。
  Future<void> setFocusAndExposurePoint(Offset point) {
    throw UnimplementedError('setFocusAndExposurePoint() は未実装です。');
  }

  /// AE/AF ロックの有無を設定する。
  Future<void> setFocusAndExposureLocked({required bool locked}) {
    throw UnimplementedError('setFocusAndExposureLocked() は未実装です。');
  }

  /// 露出補正値（EV）を設定する。
  Future<void> setExposureOffset(double offset) {
    throw UnimplementedError('setExposureOffset() は未実装です。');
  }

  /// フラッシュモードを設定する。
  Future<void> setFlashMode(FlashMode mode) {
    throw UnimplementedError('setFlashMode() は未実装です。');
  }

  /// システムギャラリーで指定した画像を開く。
  ///
  /// Android は指定画像を直接開く。iOS には特定アセットを開く公開 API が
  /// ないため、Photos アプリを前面に出すのみで画像の指定はできない。
  Future<void> openInGallery(String galleryUri) {
    throw UnimplementedError('openInGallery() は未実装です。');
  }

  /// システムギャラリーから指定した画像を削除する。
  Future<bool> deleteFromGallery(String galleryUri) {
    throw UnimplementedError('deleteFromGallery() は未実装です。');
  }
}
