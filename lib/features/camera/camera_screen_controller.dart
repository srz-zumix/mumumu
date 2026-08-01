import 'dart:async';
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silent_camera/silent_camera.dart';

import '../../core/logging/app_logger.dart';
import '../../core/permissions/permission_service.dart';
import '../../core/preferences/app_settings.dart';
import '../../core/preferences/settings_controller.dart';
import '../../platform/silent_camera_providers.dart';

/// カメラ画面の状態。
@immutable
class CameraScreenState {
  /// カメラ画面の状態を生成する。
  const CameraScreenState({
    this.isInitializing = false,
    this.isReady = false,
    this.isCapturing = false,
    this.countdown = 0,
    this.lastCapture,
    this.errorMessage,
    this.cameraPermission = AppPermissionStatus.notDetermined,
    this.galleryPermission = AppPermissionStatus.notDetermined,
  });

  /// 初期化中かどうか。
  final bool isInitializing;

  /// 撮影可能かどうか。
  final bool isReady;

  /// 撮影処理中かどうか。
  final bool isCapturing;

  /// セルフタイマーの残り秒数（0 のときは非表示）。
  final int countdown;

  /// 直近の撮影結果。サムネイル表示に用いる。
  final CaptureResult? lastCapture;

  /// 表示中のエラーメッセージ。
  final String? errorMessage;

  /// カメラ権限の状態。
  final AppPermissionStatus cameraPermission;

  /// 写真ライブラリ権限の状態。
  final AppPermissionStatus galleryPermission;

  /// シャッター操作を受け付けられるかどうか。
  bool get canShoot => isReady && !isCapturing && countdown == 0;

  /// 一部の値を差し替えた状態を返す。
  CameraScreenState copyWith({
    bool? isInitializing,
    bool? isReady,
    bool? isCapturing,
    int? countdown,
    CaptureResult? lastCapture,
    String? errorMessage,
    bool clearError = false,
    AppPermissionStatus? cameraPermission,
    AppPermissionStatus? galleryPermission,
  }) {
    return CameraScreenState(
      isInitializing: isInitializing ?? this.isInitializing,
      isReady: isReady ?? this.isReady,
      isCapturing: isCapturing ?? this.isCapturing,
      countdown: countdown ?? this.countdown,
      lastCapture: lastCapture ?? this.lastCapture,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      cameraPermission: cameraPermission ?? this.cameraPermission,
      galleryPermission: galleryPermission ?? this.galleryPermission,
    );
  }
}

/// カメラ画面の状態を管理する。
final NotifierProvider<CameraScreenController, CameraScreenState>
cameraScreenProvider =
    NotifierProvider<CameraScreenController, CameraScreenState>(
      CameraScreenController.new,
    );

/// カメラ画面のユースケースを実装するコントローラ。
///
/// 権限確認 → カメラ初期化 → 撮影 → 保存という仕様書 5.1 の流れを担う。
class CameraScreenController extends Notifier<CameraScreenState> {
  static const AppLogger _logger = AppLogger('camera');

  Timer? _countdownTimer;

  SilentCameraController get _camera =>
      ref.read(silentCameraControllerProvider);

  PermissionService get _permissions => ref.read(permissionServiceProvider);

  AppSettings get _settings => ref.read(settingsProvider);

  @override
  CameraScreenState build() {
    ref.onDispose(() {
      _countdownTimer?.cancel();
    });
    return const CameraScreenState();
  }

  /// 権限確認を行い、カメラを初期化する。
  Future<void> start() async {
    if (state.isInitializing) {
      return;
    }
    state = state.copyWith(isInitializing: true, clearError: true);

    AppPermissionStatus camera = (await _permissions.check()).camera;
    if (camera != AppPermissionStatus.granted) {
      camera = await _permissions.requestCamera();
    }
    state = state.copyWith(cameraPermission: camera);

    if (camera != AppPermissionStatus.granted) {
      state = state.copyWith(
        isInitializing: false,
        isReady: false,
        errorMessage: 'カメラの権限が必要です。設定から許可してください。',
      );
      return;
    }

    try {
      final AppSettings settings = _settings;
      await _camera.initialize(
        resolution: settings.resolution,
        captureMode: settings.captureMode,
      );
      await _camera.setFlashMode(settings.flashMode);
      state = state.copyWith(isInitializing: false, isReady: true);
    } on SilentCameraException catch (e, stack) {
      _logger.error('カメラの初期化に失敗しました', e, stack);
      state = state.copyWith(
        isInitializing: false,
        isReady: false,
        errorMessage: e.message,
      );
    }
  }

  /// カメラを解放する。
  Future<void> stop() async {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    state = state.copyWith(isReady: false, countdown: 0);
    await _camera.release();
  }

  /// 前面 / 背面カメラを切り替える。
  Future<void> switchCamera() async {
    if (!state.isReady) {
      return;
    }
    state = state.copyWith(isReady: false);
    try {
      await _camera.switchCamera();
      await _camera.setFlashMode(_settings.flashMode);
      state = state.copyWith(isReady: true, clearError: true);
    } on SilentCameraException catch (e, stack) {
      _logger.error('カメラの切り替えに失敗しました', e, stack);
      state = state.copyWith(errorMessage: e.message);
    }
  }

  /// フラッシュモードを設定し、設定値として保存する。
  Future<void> setFlashMode(FlashMode mode) async {
    await ref.read(settingsProvider.notifier).setFlashMode(mode);
    if (state.isReady) {
      await _camera.setFlashMode(mode);
    }
  }

  /// ズーム倍率を設定する。
  Future<void> setZoomLevel(double zoom) => _camera.setZoomLevel(zoom);

  /// タップ位置にフォーカスと露出を合わせる。
  Future<void> focusAt(Offset point) => _camera.setFocusAndExposurePoint(point);

  /// AE/AF ロックを切り替える。
  Future<void> toggleFocusLock() {
    final bool locked = !_camera.value.isFocusAndExposureLocked;
    return _camera.setFocusAndExposureLocked(locked: locked);
  }

  /// 露出補正値を設定する。
  Future<void> setExposureOffset(double offset) =>
      _camera.setExposureOffset(offset);

  /// 解像度・アスペクト比などの設定変更をカメラへ反映する。
  Future<void> applySettings() async {
    if (!state.isReady) {
      return;
    }
    final AppSettings settings = _settings;
    final SilentCameraValue value = _camera.value;
    if (value.resolution != settings.resolution) {
      await _camera.setResolution(settings.resolution);
    }
    if (value.captureMode != settings.captureMode) {
      await _camera.setCaptureMode(settings.captureMode);
    }
    if (value.flashMode != settings.flashMode) {
      await _camera.setFlashMode(settings.flashMode);
    }
  }

  /// セルフタイマーを考慮して撮影する。
  Future<void> shoot() async {
    if (!state.canShoot) {
      return;
    }

    final int seconds = _settings.selfTimer.seconds;
    if (seconds > 0) {
      await _runCountdown(seconds);
      // カウントダウン中に画面を離れた場合は撮影しない。
      if (state.countdown != 0) {
        return;
      }
    }
    await _capture();
  }

  Future<void> _runCountdown(int seconds) {
    final Completer<void> completer = Completer<void>();
    state = state.copyWith(countdown: seconds);
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      final int remaining = state.countdown - 1;
      state = state.copyWith(countdown: remaining < 0 ? 0 : remaining);
      if (state.countdown <= 0) {
        timer.cancel();
        _countdownTimer = null;
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    });
    return completer.future;
  }

  Future<void> _capture() async {
    AppPermissionStatus gallery = (await _permissions.check()).photoLibrary;
    if (gallery != AppPermissionStatus.granted) {
      gallery = await _permissions.requestPhotoLibrary();
    }
    state = state.copyWith(galleryPermission: gallery);

    final bool saveToGallery = gallery == AppPermissionStatus.granted;
    final AppSettings settings = _settings;

    state = state.copyWith(isCapturing: true, clearError: true);
    try {
      final CaptureResult result = await _camera.capture(
        CaptureOptions(
          saveToGallery: saveToGallery,
          jpegQuality: settings.jpegQuality,
          format: settings.format,
          aspectRatio: settings.aspectRatio,
          mirrorFrontCamera: settings.mirrorFrontCamera,
          includeLocation: settings.includeLocation,
        ),
      );
      state = state.copyWith(
        isCapturing: false,
        lastCapture: result,
        errorMessage: saveToGallery ? null : '写真ライブラリの権限がないため、端末には保存されていません。',
      );
    } on SilentCameraException catch (e, stack) {
      _logger.error('撮影に失敗しました', e, stack);
      state = state.copyWith(isCapturing: false, errorMessage: e.message);
    }
  }

  /// エラーメッセージを消す。
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// 直近の撮影結果を破棄する（ビューアで削除した場合など）。
  void clearLastCapture() {
    state = CameraScreenState(
      isInitializing: state.isInitializing,
      isReady: state.isReady,
      isCapturing: state.isCapturing,
      countdown: state.countdown,
      cameraPermission: state.cameraPermission,
      galleryPermission: state.galleryPermission,
    );
  }
}
