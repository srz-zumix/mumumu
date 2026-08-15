import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// 露出補正スライダー。仕様書 5.1「フォーカス / 露出」に対応する。
class ExposureSlider extends StatelessWidget {
  /// 露出補正スライダーを生成する。
  const ExposureSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    super.key,
  });

  /// 現在の露出補正値（EV）。
  final double value;

  /// 露出補正の下限。
  final double min;

  /// 露出補正の上限。
  final double max;

  /// 露出補正の変更要求。
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    if (max <= min) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Icon(
          Icons.brightness_6,
          size: 20,
          color: AppTheme.cameraForeground,
        ),
        SizedBox(
          height: 180,
          child: RotatedBox(
            quarterTurns: 3,
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              label: '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)} EV',
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
