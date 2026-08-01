import 'dart:io';

import 'package:flutter/material.dart';
import 'package:silent_camera/silent_camera.dart';

import '../../../app/theme.dart';

/// カメラ画面の下部バー。
///
/// 仕様書 6-2 のとおり、直近サムネイル / シャッターボタン / カメラ切替を並べる。
class CameraBottomBar extends StatelessWidget {
  /// 下部バーを生成する。
  const CameraBottomBar({
    required this.lastCapture,
    required this.canShoot,
    required this.isCapturing,
    required this.onShutterPressed,
    required this.onThumbnailPressed,
    required this.onSwitchCameraPressed,
    super.key,
  });

  /// 直近の撮影結果。
  final CaptureResult? lastCapture;

  /// シャッターを押せるかどうか。
  final bool canShoot;

  /// 撮影処理中かどうか。
  final bool isCapturing;

  /// シャッター操作。
  final VoidCallback onShutterPressed;

  /// サムネイルのタップ操作。
  final VoidCallback onThumbnailPressed;

  /// カメラ切り替え操作。
  final VoidCallback onSwitchCameraPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            _Thumbnail(capture: lastCapture, onPressed: onThumbnailPressed),
            _ShutterButton(
              enabled: canShoot,
              isCapturing: isCapturing,
              onPressed: onShutterPressed,
            ),
            IconButton(
              tooltip: 'カメラ切替',
              iconSize: 32,
              color: AppTheme.cameraForeground,
              onPressed: canShoot ? onSwitchCameraPressed : null,
              disabledColor: AppTheme.cameraForeground.withValues(alpha: 0.3),
              icon: const Icon(Icons.cameraswitch),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.capture, required this.onPressed});

  final CaptureResult? capture;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final CaptureResult? result = capture;
    return SizedBox(
      width: 56,
      height: 56,
      child: result == null
          ? const SizedBox.shrink()
          : GestureDetector(
              onTap: onPressed,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(result.filePath),
                  fit: BoxFit.cover,
                  errorBuilder:
                      (BuildContext context, Object error, StackTrace? stack) =>
                          const ColoredBox(color: AppTheme.cameraOverlay),
                ),
              ),
            ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({
    required this.enabled,
    required this.isCapturing,
    required this.onPressed,
  });

  final bool enabled;
  final bool isCapturing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '撮影',
      child: GestureDetector(
        onTap: enabled ? onPressed : null,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.cameraForeground, width: 4),
            color: enabled
                ? AppTheme.cameraForeground.withValues(alpha: 0.9)
                : AppTheme.cameraForeground.withValues(alpha: 0.3),
          ),
          child: isCapturing
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(strokeWidth: 3),
                )
              : null,
        ),
      ),
    );
  }
}
