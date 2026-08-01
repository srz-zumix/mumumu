import 'dart:ui' show Offset, Size;

import 'package:flutter/foundation.dart';

import 'models.dart';
import 'silent_camera_platform_interface.dart';

/// [SilentCameraController] が保持する状態。
@immutable
class SilentCameraValue {
  /// 状態を生成する。
  const SilentCameraValue({
    this.isInitialized = false,
    this.isCapturing = false,
    this.textureId,
    this.previewSize,
    this.previewQuarterTurns = 0,
    this.previewFlipHorizontally = false,
    this.description,
    this.captureMode = CaptureMode.silentVideoFrame,
    this.resolution = CaptureResolution.max,
    this.flashMode = FlashMode.off,
    this.zoomLevel = 1,
    this.minZoom = 1,
    this.maxZoom = 1,
    this.zoomPresets = const <double>[1],
    this.exposureOffset = 0,
    this.minExposureOffset = 0,
    this.maxExposureOffset = 0,
    this.exposureOffsetStep = 0,
    this.isFocusAndExposureLocked = false,
    this.focusPoint,
    this.errorMessage,
  });

  /// 初期化済みかどうか。
  final bool isInitialized;

  /// 撮影処理中かどうか。
  final bool isCapturing;

  /// プレビュー描画用テクスチャ ID。
  final int? textureId;

  /// プレビューサイズ。
  final Size? previewSize;

  /// テクスチャを表示する際の 90 度単位の回転数。
  final int previewQuarterTurns;

  /// 表示時に左右反転するかどうか。
  final bool previewFlipHorizontally;

  /// 現在のカメラ情報。
  final CameraDescription? description;

  /// キャプチャ方式。
  final CaptureMode captureMode;

  /// 解像度プリセット。
  final CaptureResolution resolution;

  /// フラッシュモード。
  final FlashMode flashMode;

  /// 現在のズーム倍率。
  final double zoomLevel;

  /// 最小ズーム倍率。
  final double minZoom;

  /// 最大ズーム倍率。
  final double maxZoom;

  /// 倍率ボタン用のプリセット。
  final List<double> zoomPresets;

  /// 露出補正値（EV）。
  final double exposureOffset;

  /// 露出補正の下限。
  final double minExposureOffset;

  /// 露出補正の上限。
  final double maxExposureOffset;

  /// 露出補正の刻み幅。
  final double exposureOffsetStep;

  /// AE/AF ロック中かどうか。
  final bool isFocusAndExposureLocked;

  /// 直近のフォーカス指定点（0.0-1.0 のプレビュー相対座標）。
  final Offset? focusPoint;

  /// エラーメッセージ。
  final String? errorMessage;

  /// フラッシュが利用可能かどうか。
  bool get hasFlash => description?.hasFlash ?? false;

  /// 一部の値を差し替えた新しい状態を返す。
  SilentCameraValue copyWith({
    bool? isInitialized,
    bool? isCapturing,
    int? textureId,
    Size? previewSize,
    int? previewQuarterTurns,
    bool? previewFlipHorizontally,
    CameraDescription? description,
    CaptureMode? captureMode,
    CaptureResolution? resolution,
    FlashMode? flashMode,
    double? zoomLevel,
    double? minZoom,
    double? maxZoom,
    List<double>? zoomPresets,
    double? exposureOffset,
    double? minExposureOffset,
    double? maxExposureOffset,
    double? exposureOffsetStep,
    bool? isFocusAndExposureLocked,
    Offset? focusPoint,
    bool clearFocusPoint = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SilentCameraValue(
      isInitialized: isInitialized ?? this.isInitialized,
      isCapturing: isCapturing ?? this.isCapturing,
      textureId: textureId ?? this.textureId,
      previewSize: previewSize ?? this.previewSize,
      previewQuarterTurns: previewQuarterTurns ?? this.previewQuarterTurns,
      previewFlipHorizontally:
          previewFlipHorizontally ?? this.previewFlipHorizontally,
      description: description ?? this.description,
      captureMode: captureMode ?? this.captureMode,
      resolution: resolution ?? this.resolution,
      flashMode: flashMode ?? this.flashMode,
      zoomLevel: zoomLevel ?? this.zoomLevel,
      minZoom: minZoom ?? this.minZoom,
      maxZoom: maxZoom ?? this.maxZoom,
      zoomPresets: zoomPresets ?? this.zoomPresets,
      exposureOffset: exposureOffset ?? this.exposureOffset,
      minExposureOffset: minExposureOffset ?? this.minExposureOffset,
      maxExposureOffset: maxExposureOffset ?? this.maxExposureOffset,
      exposureOffsetStep: exposureOffsetStep ?? this.exposureOffsetStep,
      isFocusAndExposureLocked:
          isFocusAndExposureLocked ?? this.isFocusAndExposureLocked,
      focusPoint: clearFocusPoint ? null : (focusPoint ?? this.focusPoint),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// 無音カメラの高レベル API。
///
/// プラットフォーム実装（[SilentCameraPlatform]）を包み、
/// UI から扱いやすい形で状態と操作を提供する。
class SilentCameraController extends ValueNotifier<SilentCameraValue> {
  /// 無音カメラのコントローラを生成する。
  SilentCameraController({SilentCameraPlatform? platform})
    : _platform = platform ?? SilentCameraPlatform.instance,
      super(const SilentCameraValue());

  final SilentCameraPlatform _platform;
  bool _disposed = false;

  /// 端末の無音撮影対応状況を取得する。
  Future<SilenceCapability> getSilenceCapability() =>
      _platform.getSilenceCapability();

  /// 利用可能なカメラの一覧を取得する。
  Future<List<CameraDescription>> availableCameras() =>
      _platform.availableCameras();

  /// カメラを初期化する。
  Future<void> initialize({
    CameraLensDirection lensDirection = CameraLensDirection.back,
    CaptureResolution resolution = CaptureResolution.max,
    CaptureMode captureMode = CaptureMode.silentVideoFrame,
  }) async {
    try {
      final CameraInitializationResult result = await _platform.initialize(
        lensDirection: lensDirection,
        resolution: resolution,
        captureMode: captureMode,
      );
      _update(
        value.copyWith(
          isInitialized: true,
          textureId: result.textureId,
          previewSize: result.previewSize,
          previewQuarterTurns: result.previewQuarterTurns,
          previewFlipHorizontally: result.previewFlipHorizontally,
          description: result.description,
          resolution: resolution,
          captureMode: captureMode,
          zoomLevel: 1,
          minZoom: result.description.minZoom,
          maxZoom: result.description.maxZoom,
          zoomPresets: result.description.zoomPresets,
          exposureOffset: 0,
          minExposureOffset: result.minExposureOffset,
          maxExposureOffset: result.maxExposureOffset,
          exposureOffsetStep: result.exposureOffsetStep,
          isFocusAndExposureLocked: false,
          clearFocusPoint: true,
          clearError: true,
        ),
      );
    } on SilentCameraException catch (e) {
      _update(value.copyWith(isInitialized: false, errorMessage: e.message));
      rethrow;
    }
  }

  /// 前面 / 背面カメラを切り替える。
  Future<void> switchCamera() async {
    final CameraLensDirection current =
        value.description?.lensDirection ?? CameraLensDirection.back;
    final CameraLensDirection next = current == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    _update(value.copyWith(isInitialized: false));
    await _platform.dispose();
    await initialize(
      lensDirection: next,
      resolution: value.resolution,
      captureMode: value.captureMode,
    );
  }

  /// キャプチャ方式を切り替える。
  Future<void> setCaptureMode(CaptureMode mode) async {
    if (mode == value.captureMode) {
      return;
    }
    _update(value.copyWith(isInitialized: false));
    await _platform.dispose();
    await initialize(
      lensDirection:
          value.description?.lensDirection ?? CameraLensDirection.back,
      resolution: value.resolution,
      captureMode: mode,
    );
  }

  /// 解像度プリセットを変更する。
  Future<void> setResolution(CaptureResolution resolution) async {
    if (resolution == value.resolution) {
      return;
    }
    _update(value.copyWith(isInitialized: false));
    await _platform.dispose();
    await initialize(
      lensDirection:
          value.description?.lensDirection ?? CameraLensDirection.back,
      resolution: resolution,
      captureMode: value.captureMode,
    );
  }

  /// 静止画を撮影する。
  Future<CaptureResult> capture(CaptureOptions options) async {
    if (value.isCapturing) {
      throw const SilentCameraException('busy', '撮影処理が進行中です。');
    }
    _update(value.copyWith(isCapturing: true, clearError: true));
    try {
      return await _platform.capture(options);
    } on SilentCameraException catch (e) {
      _update(value.copyWith(errorMessage: e.message));
      rethrow;
    } finally {
      _update(value.copyWith(isCapturing: false));
    }
  }

  /// ズーム倍率を設定する。
  Future<void> setZoomLevel(double zoom) async {
    final double clamped = zoom.clamp(value.minZoom, value.maxZoom);
    if (clamped == value.zoomLevel) {
      return;
    }
    await _platform.setZoomLevel(clamped);
    _update(value.copyWith(zoomLevel: clamped));
  }

  /// フォーカスと露出の測定点を設定する。
  Future<void> setFocusAndExposurePoint(Offset point) async {
    await _platform.setFocusAndExposurePoint(point);
    _update(value.copyWith(focusPoint: point, isFocusAndExposureLocked: false));
  }

  /// AE/AF ロックを切り替える。
  Future<void> setFocusAndExposureLocked({required bool locked}) async {
    await _platform.setFocusAndExposureLocked(locked: locked);
    _update(value.copyWith(isFocusAndExposureLocked: locked));
  }

  /// 露出補正値を設定する。
  Future<void> setExposureOffset(double offset) async {
    final double clamped = offset.clamp(
      value.minExposureOffset,
      value.maxExposureOffset,
    );
    await _platform.setExposureOffset(clamped);
    _update(value.copyWith(exposureOffset: clamped));
  }

  /// フラッシュモードを設定する。
  Future<void> setFlashMode(FlashMode mode) async {
    await _platform.setFlashMode(mode);
    _update(value.copyWith(flashMode: mode));
  }

  /// プレビューを一時停止する。
  Future<void> pausePreview() => _platform.pausePreview();

  /// プレビューを再開する。
  Future<void> resumePreview() => _platform.resumePreview();

  /// システムギャラリーで開く。
  Future<void> openInGallery(String galleryUri) =>
      _platform.openInGallery(galleryUri);

  /// システムギャラリーから削除する。
  Future<bool> deleteFromGallery(String galleryUri) =>
      _platform.deleteFromGallery(galleryUri);

  /// カメラを解放する。
  Future<void> release() async {
    if (!value.isInitialized) {
      return;
    }
    _update(value.copyWith(isInitialized: false));
    await _platform.dispose();
  }

  void _update(SilentCameraValue newValue) {
    if (_disposed) {
      return;
    }
    value = newValue;
  }

  @override
  void dispose() {
    _disposed = true;
    _platform.dispose().catchError((Object _) {});
    super.dispose();
  }
}
