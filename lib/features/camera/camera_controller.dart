import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silent_camera/silent_camera.dart';

import '../../core/permissions.dart';
import '../../core/settings/settings_controller.dart';

/// カメラ画面の状態。
@immutable
class CameraState {
  const CameraState({
    this.session,
    this.cameras = const <SilentCameraDescription>[],
    this.capability,
    this.flashMode = FlashMode.off,
    this.zoomLevel = 1,
    this.exposureOffset = 0,
    this.isLocked = false,
    this.isCapturing = false,
    this.countdown = 0,
    this.lastCapture,
    this.errorMessage,
    this.permissionOutcome,
  });

  final SilentCameraSession? session;
  final List<SilentCameraDescription> cameras;
  final SilenceCapability? capability;
  final FlashMode flashMode;
  final double zoomLevel;
  final double exposureOffset;
  final bool isLocked;
  final bool isCapturing;

  /// セルフタイマーの残り秒数（0 はカウントダウン中でない）。
  final int countdown;
  final CaptureResult? lastCapture;
  final String? errorMessage;
  final PermissionOutcome? permissionOutcome;

  bool get isReady => session != null;

  CameraLensDirection get lensDirection =>
      session?.description.lensDirection ?? CameraLensDirection.back;

  CameraState copyWith({
    SilentCameraSession? session,
    List<SilentCameraDescription>? cameras,
    SilenceCapability? capability,
    FlashMode? flashMode,
    double? zoomLevel,
    double? exposureOffset,
    bool? isLocked,
    bool? isCapturing,
    int? countdown,
    CaptureResult? lastCapture,
    String? errorMessage,
    PermissionOutcome? permissionOutcome,
    bool clearSession = false,
    bool clearError = false,
  }) {
    return CameraState(
      session: clearSession ? null : session ?? this.session,
      cameras: cameras ?? this.cameras,
      capability: capability ?? this.capability,
      flashMode: flashMode ?? this.flashMode,
      zoomLevel: zoomLevel ?? this.zoomLevel,
      exposureOffset: exposureOffset ?? this.exposureOffset,
      isLocked: isLocked ?? this.isLocked,
      isCapturing: isCapturing ?? this.isCapturing,
      countdown: countdown ?? this.countdown,
      lastCapture: lastCapture ?? this.lastCapture,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      permissionOutcome: permissionOutcome ?? this.permissionOutcome,
    );
  }
}

/// カメラ画面のコントローラ。
final NotifierProvider<CameraController, CameraState> cameraControllerProvider =
    NotifierProvider<CameraController, CameraState>(CameraController.new);

/// 無音カメラの初期化・撮影・パラメータ変更を担うコントローラ。
class CameraController extends Notifier<CameraState> {
  SilentCamera get _camera => ref.read(silentCameraProvider);

  Timer? _timer;

  @override
  CameraState build() {
    ref.onDispose(() {
      _timer?.cancel();
      unawaited(_camera.dispose());
    });
    return const CameraState();
  }

  /// 権限を確認したうえでカメラを初期化する。
  Future<void> initialize({
    CameraLensDirection lensDirection = CameraLensDirection.back,
  }) async {
    final permission =
        await ref.read(permissionServiceProvider).requestCapturePermissions();
    state = state.copyWith(permissionOutcome: permission);
    if (permission != PermissionOutcome.granted) {
      return;
    }

    final settings = ref.read(settingsProvider);
    try {
      final capability = await _camera.silenceCapability();
      final cameras = await _camera.availableCameras();
      final session = await _camera.initialize(
        lensDirection: lensDirection,
        captureMode: settings.captureMode,
        aspectRatio: settings.aspectRatio,
      );
      state = state.copyWith(
        session: session,
        cameras: cameras,
        capability: capability,
        zoomLevel: 1,
        exposureOffset: 0,
        isLocked: false,
        clearError: true,
      );
      await _camera.setFlashMode(state.flashMode);
    } on Object catch (error) {
      state = state.copyWith(
        clearSession: true,
        errorMessage: 'カメラを起動できませんでした: $error',
      );
    }
  }

  /// 前面 / 背面カメラを切り替える。
  Future<void> switchCamera() async {
    final next = state.lensDirection == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    await _camera.dispose();
    state = state.copyWith(clearSession: true);
    await initialize(lensDirection: next);
  }

  /// 設定変更などでセッションを作り直す。
  Future<void> restart() async {
    final direction = state.lensDirection;
    await _camera.dispose();
    state = state.copyWith(clearSession: true);
    await initialize(lensDirection: direction);
  }

  /// フラッシュ動作を切り替える。
  Future<void> cycleFlashMode() async {
    const order = <FlashMode>[
      FlashMode.off,
      FlashMode.auto,
      FlashMode.on,
      FlashMode.torch,
    ];
    final next = order[(order.indexOf(state.flashMode) + 1) % order.length];
    state = state.copyWith(flashMode: next);
    await _camera.setFlashMode(next);
  }

  /// ズーム倍率を設定する。
  Future<void> setZoomLevel(double zoom) async {
    final description = state.session?.description;
    final clamped = description == null
        ? zoom
        : zoom.clamp(description.minZoom, description.maxZoom).toDouble();
    state = state.copyWith(zoomLevel: clamped);
    await _camera.setZoomLevel(clamped);
  }

  /// 露出補正を設定する。
  Future<void> setExposureOffset(double offset) async {
    final session = state.session;
    final clamped = session == null
        ? offset
        : offset
            .clamp(session.minExposureOffset, session.maxExposureOffset)
            .toDouble();
    state = state.copyWith(exposureOffset: clamped);
    await _camera.setExposureOffset(clamped);
  }

  /// タップ位置にフォーカスと露出を合わせる。
  Future<void> focusAt(double x, double y) async {
    if (!state.isReady) {
      return;
    }
    if (state.isLocked) {
      await setFocusExposureLocked(locked: false);
    }
    await _camera.setFocusPoint(x, y);
  }

  /// AE/AF ロックを設定する。
  Future<void> setFocusExposureLocked({required bool locked}) async {
    state = state.copyWith(isLocked: locked);
    await _camera.setFocusExposureLocked(locked: locked);
  }

  /// セルフタイマー設定を考慮して撮影する。
  Future<CaptureResult?> capture() async {
    if (!state.isReady || state.isCapturing || state.countdown > 0) {
      return null;
    }
    final seconds = ref.read(settingsProvider).timerSeconds;
    if (seconds > 0) {
      await _runCountdown(seconds);
    }
    return _captureNow();
  }

  Future<void> _runCountdown(int seconds) async {
    for (var remaining = seconds; remaining > 0; remaining--) {
      state = state.copyWith(countdown: remaining);
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    state = state.copyWith(countdown: 0);
  }

  Future<CaptureResult?> _captureNow() async {
    final settings = ref.read(settingsProvider);
    state = state.copyWith(isCapturing: true, clearError: true);
    try {
      final result = await _camera.capture(
        format: settings.photoFormat,
        jpegQuality: settings.jpegQuality,
        includeLocation: settings.saveLocation,
        mirrorFrontCamera: settings.mirrorFrontCamera &&
            state.lensDirection == CameraLensDirection.front,
      );
      state = state.copyWith(lastCapture: result, isCapturing: false);
      return result;
    } on Object catch (error) {
      state = state.copyWith(
        isCapturing: false,
        errorMessage: '撮影に失敗しました: $error',
      );
      return null;
    }
  }

  /// エラー表示を消す。
  void clearError() => state = state.copyWith(clearError: true);

  /// アプリがバックグラウンドへ移る際にセッションを解放する。
  Future<void> suspend() async {
    if (!state.isReady) {
      return;
    }
    await _camera.dispose();
    state = state.copyWith(clearSession: true);
  }
}

/// テストから差し替え可能な `SilentCamera` の提供元。
final Provider<SilentCamera> silentCameraProvider =
    Provider<SilentCamera>((Ref ref) => SilentCamera.instance);
