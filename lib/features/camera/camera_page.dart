import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silent_camera/silent_camera.dart';

import '../../core/permissions.dart';
import '../../core/settings/settings_controller.dart';
import '../settings/settings_page.dart';
import '../viewer/viewer_page.dart';
import 'camera_controller.dart';
import 'widgets/grid_overlay.dart';
import 'widgets/shutter_button.dart';
import 'widgets/zoom_control.dart';

/// メインのカメラ画面。
class CameraPage extends ConsumerStatefulWidget {
  const CameraPage({super.key});

  static const String routeName = '/camera';

  @override
  ConsumerState<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends ConsumerState<CameraPage>
    with WidgetsBindingObserver {
  double _zoomOnGestureStart = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cameraControllerProvider.notifier).initialize();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(cameraControllerProvider.notifier);
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        controller.suspend();
      case AppLifecycleState.resumed:
        if (!ref.read(cameraControllerProvider).isReady) {
          controller.initialize();
        }
    }
  }

  Future<void> _capture() async {
    final result =
        await ref.read(cameraControllerProvider.notifier).capture();
    if (!mounted || result == null) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 1),
        content: Text('保存しました'),
      ),
    );
  }

  Future<void> _openViewer(CaptureResult capture) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ViewerPage(capture: capture),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cameraControllerProvider);
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(cameraControllerProvider.notifier);

    ref.listen<String?>(
      cameraControllerProvider.select((CameraState s) => s.errorMessage),
      (String? previous, String? next) {
        if (next == null) {
          return;
        }
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next)));
        controller.clearError();
      },
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            Center(child: _buildPreviewArea(state, settings.gridEnabled)),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _TopBar(
                flashMode: state.flashMode,
                gridEnabled: settings.gridEnabled,
                timerSeconds: settings.timerSeconds,
                onFlashPressed: controller.cycleFlashMode,
                onGridPressed: () => ref
                    .read(settingsProvider.notifier)
                    .setGridEnabled(enabled: !settings.gridEnabled),
                onTimerPressed: _cycleTimer,
                onSettingsPressed: _openSettings,
              ),
            ),
            if (state.session != null)
              Positioned(
                right: 8,
                top: 72,
                bottom: 140,
                child: _ExposureSlider(
                  value: state.exposureOffset,
                  min: state.session!.minExposureOffset,
                  max: state.session!.maxExposureOffset,
                  onChanged: controller.setExposureOffset,
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _BottomBar(
                state: state,
                onShutter: _capture,
                onSwitchCamera: controller.switchCamera,
                onThumbnailTap: state.lastCapture == null
                    ? null
                    : () => _openViewer(state.lastCapture!),
                onZoomChanged: controller.setZoomLevel,
              ),
            ),
            if (state.countdown > 0)
              Center(
                child: Text(
                  '${state.countdown}',
                  style: const TextStyle(
                    fontSize: 96,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewArea(CameraState state, bool gridEnabled) {
    if (state.permissionOutcome != null &&
        state.permissionOutcome != PermissionOutcome.granted) {
      return _PermissionNotice(
        permanentlyDenied:
            state.permissionOutcome == PermissionOutcome.permanentlyDenied,
        onRetry: () =>
            ref.read(cameraControllerProvider.notifier).initialize(),
        onOpenSettings: () =>
            ref.read(permissionServiceProvider).openSettings(),
      );
    }
    final session = state.session;
    if (session == null) {
      return const CircularProgressIndicator();
    }
    final settings = ref.watch(settingsProvider);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (state.capability != null && !state.capability!.isSilent)
          _SilenceWarning(capability: state.capability!),
        GestureDetector(
          onTapUp: (TapUpDetails details) =>
              _handleTap(details, session, settings.tapToShoot),
          onLongPress: () => ref
              .read(cameraControllerProvider.notifier)
              .setFocusExposureLocked(locked: !state.isLocked),
          onScaleStart: (_) => _zoomOnGestureStart = state.zoomLevel,
          onScaleUpdate: (ScaleUpdateDetails details) {
            if (details.pointerCount < 2) {
              return;
            }
            ref
                .read(cameraControllerProvider.notifier)
                .setZoomLevel(_zoomOnGestureStart * details.scale);
          },
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              SilentCameraPreview(
                session: session,
                aspectRatio: settings.aspectRatio,
              ),
              if (gridEnabled) const Positioned.fill(child: GridOverlay()),
              if (state.isLocked)
                const Positioned(
                  top: 8,
                  child: _Badge(text: 'AE/AF ロック'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _handleTap(
    TapUpDetails details,
    SilentCameraSession session,
    bool tapToShoot,
  ) {
    if (tapToShoot) {
      _capture();
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) {
      return;
    }
    final local = box.globalToLocal(details.globalPosition);
    final x = (local.dx / box.size.width).clamp(0.0, 1.0).toDouble();
    final y = (local.dy / box.size.height).clamp(0.0, 1.0).toDouble();
    ref.read(cameraControllerProvider.notifier).focusAt(x, y);
  }

  void _cycleTimer() {
    const values = <int>[0, 3, 5, 10];
    final current = ref.read(settingsProvider).timerSeconds;
    final next = values[(values.indexOf(current) + 1) % values.length];
    ref.read(settingsProvider.notifier).setTimerSeconds(next);
  }

  Future<void> _openSettings() async {
    final before = ref.read(settingsProvider);
    await Navigator.of(context).pushNamed(SettingsPage.routeName);
    if (!mounted) {
      return;
    }
    final after = ref.read(settingsProvider);
    final needsRestart = before.captureMode != after.captureMode ||
        before.aspectRatio != after.aspectRatio;
    if (needsRestart) {
      await ref.read(cameraControllerProvider.notifier).restart();
    }
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.flashMode,
    required this.gridEnabled,
    required this.timerSeconds,
    required this.onFlashPressed,
    required this.onGridPressed,
    required this.onTimerPressed,
    required this.onSettingsPressed,
  });

  final FlashMode flashMode;
  final bool gridEnabled;
  final int timerSeconds;
  final VoidCallback onFlashPressed;
  final VoidCallback onGridPressed;
  final VoidCallback onTimerPressed;
  final VoidCallback onSettingsPressed;

  IconData get _flashIcon => switch (flashMode) {
        FlashMode.off => Icons.flash_off,
        FlashMode.on => Icons.flash_on,
        FlashMode.auto => Icons.flash_auto,
        FlashMode.torch => Icons.highlight,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black38,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          IconButton(
            tooltip: 'フラッシュ',
            onPressed: onFlashPressed,
            icon: Icon(_flashIcon, color: Colors.white),
          ),
          IconButton(
            tooltip: 'グリッド',
            onPressed: onGridPressed,
            icon: Icon(
              Icons.grid_3x3,
              color: gridEnabled ? Colors.amber : Colors.white,
            ),
          ),
          TextButton.icon(
            onPressed: onTimerPressed,
            icon: const Icon(Icons.timer, color: Colors.white),
            label: Text(
              timerSeconds == 0 ? 'OFF' : '${timerSeconds}s',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          IconButton(
            tooltip: '設定',
            onPressed: onSettingsPressed,
            icon: const Icon(Icons.settings, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.state,
    required this.onShutter,
    required this.onSwitchCamera,
    required this.onThumbnailTap,
    required this.onZoomChanged,
  });

  final CameraState state;
  final VoidCallback onShutter;
  final VoidCallback onSwitchCamera;
  final VoidCallback? onThumbnailTap;
  final ValueChanged<double> onZoomChanged;

  @override
  Widget build(BuildContext context) {
    final description = state.session?.description;
    return Container(
      color: Colors.black38,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (description != null)
            ZoomControl(
              presets: description.zoomPresets,
              minZoom: description.minZoom,
              maxZoom: description.maxZoom,
              zoomLevel: state.zoomLevel,
              onChanged: onZoomChanged,
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              _Thumbnail(
                capture: state.lastCapture,
                onTap: onThumbnailTap,
              ),
              ShutterButton(
                onPressed: state.isReady ? onShutter : null,
                isCapturing: state.isCapturing,
              ),
              IconButton(
                tooltip: 'カメラ切替',
                iconSize: 32,
                onPressed: state.isReady ? onSwitchCamera : null,
                icon: const Icon(Icons.cameraswitch, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.capture, required this.onTap});

  final CaptureResult? capture;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final path = capture?.filePath;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white54),
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: path == null
            ? const Icon(Icons.photo, color: Colors.white54)
            : Image.file(File(path), fit: BoxFit.cover),
      ),
    );
  }
}

class _ExposureSlider extends StatelessWidget {
  const _ExposureSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return RotatedBox(
      quarterTurns: 3,
      child: Slider(
        value: value.clamp(min, max).toDouble(),
        min: min,
        max: max,
        label: '${value.toStringAsFixed(1)} EV',
        divisions: ((max - min) * 4).round().clamp(1, 100),
        onChanged: onChanged,
      ),
    );
  }
}

class _SilenceWarning extends StatelessWidget {
  const _SilenceWarning({required this.capability});

  final SilenceCapability capability;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.orange.shade900,
      padding: const EdgeInsets.all(8),
      child: Text(
        'この端末（${capability.deviceModel}）では無音撮影ができない場合があります。'
        '${capability.reason ?? ''}',
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}

class _PermissionNotice extends StatelessWidget {
  const _PermissionNotice({
    required this.permanentlyDenied,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final bool permanentlyDenied;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(Icons.no_photography, size: 48, color: Colors.white70),
          const SizedBox(height: 16),
          const Text(
            'カメラと写真の権限が必要です。\n撮影と保存のためだけに使用します。',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: permanentlyDenied ? onOpenSettings : onRetry,
            child: Text(permanentlyDenied ? '設定を開く' : '権限を許可する'),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.amber, fontSize: 12),
      ),
    );
  }
}
