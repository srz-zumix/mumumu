import 'package:flutter/material.dart';
import 'package:silent_camera/silent_camera.dart';

import '../../../app/theme.dart';
import '../../../core/preferences/app_settings.dart';

/// カメラ画面の上部バー。
///
/// 仕様書 6-2 のとおり、フラッシュ・グリッド・タイマー・設定を配置する。
class CameraTopBar extends StatelessWidget {
  /// 上部バーを生成する。
  const CameraTopBar({
    required this.flashMode,
    required this.hasFlash,
    required this.gridEnabled,
    required this.selfTimer,
    required this.onFlashModeChanged,
    required this.onGridToggled,
    required this.onSelfTimerChanged,
    required this.onSettingsPressed,
    super.key,
  });

  /// 現在のフラッシュモード。
  final FlashMode flashMode;

  /// 端末がフラッシュを備えるかどうか。
  final bool hasFlash;

  /// グリッド表示中かどうか。
  final bool gridEnabled;

  /// 現在のセルフタイマー設定。
  final SelfTimer selfTimer;

  /// フラッシュモードの変更要求。
  final ValueChanged<FlashMode> onFlashModeChanged;

  /// グリッド表示の切り替え要求。
  final VoidCallback onGridToggled;

  /// セルフタイマーの変更要求。
  final ValueChanged<SelfTimer> onSelfTimerChanged;

  /// 設定画面への遷移要求。
  final VoidCallback onSettingsPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            IconButton(
              tooltip: 'フラッシュ: ${_flashLabel(flashMode)}',
              onPressed: hasFlash
                  ? () => onFlashModeChanged(_nextFlash())
                  : null,
              icon: Icon(_flashIcon(flashMode)),
              color: AppTheme.cameraForeground,
              disabledColor: AppTheme.cameraForeground.withValues(alpha: 0.3),
            ),
            IconButton(
              tooltip: 'グリッド',
              onPressed: onGridToggled,
              icon: Icon(gridEnabled ? Icons.grid_on : Icons.grid_off),
              color: AppTheme.cameraForeground,
            ),
            _TimerButton(selfTimer: selfTimer, onChanged: onSelfTimerChanged),
            IconButton(
              tooltip: '設定',
              onPressed: onSettingsPressed,
              icon: const Icon(Icons.settings),
              color: AppTheme.cameraForeground,
            ),
          ],
        ),
      ),
    );
  }

  FlashMode _nextFlash() {
    const List<FlashMode> order = <FlashMode>[
      FlashMode.off,
      FlashMode.auto,
      FlashMode.on,
      FlashMode.torch,
    ];
    final int index = order.indexOf(flashMode);
    return order[(index + 1) % order.length];
  }

  static IconData _flashIcon(FlashMode mode) => switch (mode) {
    FlashMode.off => Icons.flash_off,
    FlashMode.on => Icons.flash_on,
    FlashMode.auto => Icons.flash_auto,
    FlashMode.torch => Icons.highlight,
  };

  static String _flashLabel(FlashMode mode) => switch (mode) {
    FlashMode.off => 'OFF',
    FlashMode.on => 'ON',
    FlashMode.auto => 'AUTO',
    FlashMode.torch => 'トーチ',
  };
}

class _TimerButton extends StatelessWidget {
  const _TimerButton({required this.selfTimer, required this.onChanged});

  final SelfTimer selfTimer;
  final ValueChanged<SelfTimer> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<SelfTimer>(
      tooltip: 'セルフタイマー',
      initialValue: selfTimer,
      onSelected: onChanged,
      itemBuilder: (BuildContext context) => SelfTimer.values
          .map(
            (SelfTimer timer) => PopupMenuItem<SelfTimer>(
              value: timer,
              child: Text(timer.label),
            ),
          )
          .toList(),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.timer, color: AppTheme.cameraForeground),
            if (selfTimer != SelfTimer.off) ...<Widget>[
              const SizedBox(width: 4),
              Text(
                selfTimer.label,
                style: const TextStyle(color: AppTheme.cameraForeground),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
