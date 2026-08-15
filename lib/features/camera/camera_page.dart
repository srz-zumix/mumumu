import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silent_camera/silent_camera.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/preferences/app_settings.dart';
import '../../core/preferences/settings_controller.dart';
import '../../platform/silent_camera_providers.dart';
import 'camera_screen_controller.dart';
import 'widgets/camera_bottom_bar.dart';
import 'widgets/camera_top_bar.dart';
import 'widgets/exposure_slider.dart';
import 'widgets/grid_overlay.dart';
import 'widgets/zoom_control.dart';

/// カメラ画面（メイン）。仕様書 6-2 に対応する。
class CameraPage extends ConsumerStatefulWidget {
  /// カメラ画面を生成する。
  const CameraPage({super.key});

  @override
  ConsumerState<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends ConsumerState<CameraPage>
    with WidgetsBindingObserver {
  final FocusNode _focusNode = FocusNode();

  Offset? _focusIndicator;
  Timer? _focusIndicatorTimer;
  double _zoomAtGestureStart = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 起動から撮影可能までを短くするため、フレーム描画直後に初期化を始める。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(cameraScreenProvider.notifier).start());
    });
  }

  @override
  void dispose() {
    _focusIndicatorTimer?.cancel();
    _focusNode.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraScreenController controller = ref.read(
      cameraScreenProvider.notifier,
    );
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        unawaited(controller.stop());
      case AppLifecycleState.resumed:
        unawaited(controller.start());
    }
  }

  @override
  Widget build(BuildContext context) {
    final CameraScreenState screenState = ref.watch(cameraScreenProvider);
    final AppSettings settings = ref.watch(settingsProvider);
    final SilentCameraController camera = ref.watch(
      silentCameraControllerProvider,
    );

    ref.listen<CameraScreenState>(cameraScreenProvider, (
      CameraScreenState? previous,
      CameraScreenState next,
    ) {
      final String? message = next.errorMessage;
      if (message != null && message != previous?.errorMessage) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        ref.read(cameraScreenProvider.notifier).clearError();
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.cameraBackground,
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (KeyEvent event) => _handleKeyEvent(event, settings),
        child: Column(
          children: <Widget>[
            CameraTopBar(
              flashMode: settings.flashMode,
              hasFlash: camera.value.hasFlash,
              gridEnabled: settings.gridEnabled,
              selfTimer: settings.selfTimer,
              onFlashModeChanged: (FlashMode mode) => unawaited(
                ref.read(cameraScreenProvider.notifier).setFlashMode(mode),
              ),
              onGridToggled: () => unawaited(
                ref
                    .read(settingsProvider.notifier)
                    .setGridEnabled(enabled: !settings.gridEnabled),
              ),
              onSelfTimerChanged: (SelfTimer timer) => unawaited(
                ref.read(settingsProvider.notifier).setSelfTimer(timer),
              ),
              onSettingsPressed: _openSettings,
            ),
            Expanded(child: _buildPreviewArea(screenState, settings, camera)),
            CameraBottomBar(
              lastCapture: screenState.lastCapture,
              canShoot: screenState.canShoot,
              isCapturing: screenState.isCapturing,
              onShutterPressed: _shoot,
              onThumbnailPressed: () => _openViewer(screenState.lastCapture),
              onSwitchCameraPressed: () => unawaited(
                ref.read(cameraScreenProvider.notifier).switchCamera(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewArea(
    CameraScreenState screenState,
    AppSettings settings,
    SilentCameraController camera,
  ) {
    if (!screenState.isReady) {
      return _buildPlaceholder(screenState);
    }

    return ValueListenableBuilder<SilentCameraValue>(
      valueListenable: camera,
      builder: (BuildContext context, SilentCameraValue value, Widget? _) {
        return Stack(
          alignment: Alignment.center,
          children: <Widget>[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (TapUpDetails details) => _handleTap(details, settings),
              onLongPress: () => unawaited(
                ref.read(cameraScreenProvider.notifier).toggleFocusLock(),
              ),
              onScaleStart: (_) => _zoomAtGestureStart = value.zoomLevel,
              onScaleUpdate: (ScaleUpdateDetails details) {
                if (details.pointerCount < 2) {
                  return;
                }
                unawaited(
                  ref
                      .read(cameraScreenProvider.notifier)
                      .setZoomLevel(_zoomAtGestureStart * details.scale),
                );
              },
              child: SilentCameraPreview(
                controller: camera,
                aspectRatio: 1 / settings.aspectRatio.value,
              ),
            ),
            if (settings.gridEnabled) const GridOverlay(),
            if (_focusIndicator != null)
              _FocusIndicator(position: _focusIndicator!),
            if (value.isFocusAndExposureLocked)
              const Positioned(top: 12, child: _LockBadge()),
            Positioned(
              right: 8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ZoomControl(
                    zoomLevel: value.zoomLevel,
                    minZoom: value.minZoom,
                    maxZoom: value.maxZoom,
                    presets: value.zoomPresets,
                    onChanged: (double zoom) => unawaited(
                      ref
                          .read(cameraScreenProvider.notifier)
                          .setZoomLevel(zoom),
                    ),
                  ),
                  ExposureSlider(
                    value: value.exposureOffset,
                    min: value.minExposureOffset,
                    max: value.maxExposureOffset,
                    onChanged: (double offset) => unawaited(
                      ref
                          .read(cameraScreenProvider.notifier)
                          .setExposureOffset(offset),
                    ),
                  ),
                ],
              ),
            ),
            if (screenState.countdown > 0)
              _CountdownOverlay(seconds: screenState.countdown),
            const Positioned(bottom: 8, child: _SilenceNotice()),
          ],
        );
      },
    );
  }

  Widget _buildPlaceholder(CameraScreenState screenState) {
    if (screenState.isInitializing) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.no_photography,
              size: 48,
              color: AppTheme.cameraForeground,
            ),
            const SizedBox(height: 16),
            Text(
              screenState.errorMessage ?? 'カメラを準備できませんでした。',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.cameraForeground),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () =>
                  unawaited(ref.read(cameraScreenProvider.notifier).start()),
              child: const Text('再試行'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleTap(TapUpDetails details, AppSettings settings) {
    if (settings.shutterMethod == ShutterMethod.tapAnywhere) {
      _shoot();
      return;
    }

    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) {
      return;
    }
    final Offset local = details.localPosition;
    final Size size = box.size;
    final Offset normalized = Offset(
      (local.dx / size.width).clamp(0.0, 1.0),
      (local.dy / size.height).clamp(0.0, 1.0),
    );

    unawaited(ref.read(cameraScreenProvider.notifier).focusAt(normalized));

    setState(() => _focusIndicator = local);
    _focusIndicatorTimer?.cancel();
    _focusIndicatorTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() => _focusIndicator = null);
      }
    });
  }

  /// 音量ボタンでのシャッターを処理する。
  ///
  /// iOS では音量ボタンのイベントを取得できないため Android のみ有効となる。
  void _handleKeyEvent(KeyEvent event, AppSettings settings) {
    if (settings.shutterMethod != ShutterMethod.volumeKey) {
      return;
    }
    if (event is! KeyDownEvent) {
      return;
    }
    if (event.logicalKey == LogicalKeyboardKey.audioVolumeUp ||
        event.logicalKey == LogicalKeyboardKey.audioVolumeDown) {
      _shoot();
    }
  }

  void _shoot() {
    unawaited(ref.read(cameraScreenProvider.notifier).shoot());
  }

  void _openSettings() {
    unawaited(
      Navigator.of(context).pushNamed(AppRoutes.settings).then((Object? _) {
        unawaited(ref.read(cameraScreenProvider.notifier).applySettings());
      }),
    );
  }

  void _openViewer(CaptureResult? capture) {
    if (capture == null) {
      return;
    }
    unawaited(
      Navigator.of(context).pushNamed(AppRoutes.viewer, arguments: capture),
    );
  }
}

class _FocusIndicator extends StatelessWidget {
  const _FocusIndicator({required this.position});

  final Offset position;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx - 32,
      top: position.dy - 32,
      child: IgnorePointer(
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.amber, width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

class _LockBadge extends StatelessWidget {
  const _LockBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.amber,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'AE/AF ロック',
        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _CountdownOverlay extends StatelessWidget {
  const _CountdownOverlay({required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        color: AppTheme.cameraOverlay,
        alignment: Alignment.center,
        child: Text(
          '$seconds',
          style: const TextStyle(
            color: AppTheme.cameraForeground,
            fontSize: 96,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// 端末の無音撮影対応状況を表示する。仕様書 2.3 に対応する。
class _SilenceNotice extends ConsumerWidget {
  const _SilenceNotice();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SilenceCapability> capability = ref.watch(
      silenceCapabilityProvider,
    );

    return capability.maybeWhen(
      data: (SilenceCapability value) {
        if (value.isSilentCaptureSupported && value.note.isEmpty) {
          return const SizedBox.shrink();
        }
        final String message = value.isSilentCaptureSupported
            ? value.note
            : 'この端末では静かに撮影できない場合があります。';
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.cameraOverlay,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.cameraForeground,
              fontSize: 12,
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
