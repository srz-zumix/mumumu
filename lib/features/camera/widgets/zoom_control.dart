import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// ズーム倍率のスライダーと倍率ボタン。
///
/// 仕様書 5.1「ズーム」に対応する。
class ZoomControl extends StatelessWidget {
  /// ズームコントロールを生成する。
  const ZoomControl({
    required this.zoomLevel,
    required this.minZoom,
    required this.maxZoom,
    required this.presets,
    required this.onChanged,
    super.key,
  });

  /// 現在のズーム倍率。
  final double zoomLevel;

  /// 最小ズーム倍率。
  final double minZoom;

  /// 最大ズーム倍率。
  final double maxZoom;

  /// 倍率ボタンとして表示する値。
  final List<double> presets;

  /// ズーム変更要求。
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    if (maxZoom <= minZoom) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (presets.length > 1)
          Wrap(
            spacing: 8,
            children: presets
                .map(
                  (double preset) => _ZoomChip(
                    value: preset,
                    selected: (zoomLevel - preset).abs() < 0.05,
                    onPressed: () => onChanged(preset),
                  ),
                )
                .toList(),
          ),
        SizedBox(
          height: 220,
          child: RotatedBox(
            quarterTurns: 3,
            child: Slider(
              value: zoomLevel.clamp(minZoom, maxZoom),
              min: minZoom,
              max: maxZoom,
              label: '${zoomLevel.toStringAsFixed(1)}x',
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _ZoomChip extends StatelessWidget {
  const _ZoomChip({
    required this.value,
    required this.selected,
    required this.onPressed,
  });

  final double value;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.cameraForeground.withValues(alpha: 0.85)
              : AppTheme.cameraOverlay,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          '${_format(value)}x',
          style: TextStyle(
            color: selected ? Colors.black : AppTheme.cameraForeground,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  static String _format(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }
}
