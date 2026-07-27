import 'package:flutter/material.dart';

/// 倍率プリセットボタンとズームスライダー。
class ZoomControl extends StatelessWidget {
  const ZoomControl({
    required this.presets,
    required this.minZoom,
    required this.maxZoom,
    required this.zoomLevel,
    required this.onChanged,
    super.key,
  });

  final List<double> presets;
  final double minZoom;
  final double maxZoom;
  final double zoomLevel;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            for (final preset in presets)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _ZoomChip(
                  zoom: preset,
                  selected: (zoomLevel - preset).abs() < 0.05,
                  onTap: () => onChanged(preset),
                ),
              ),
          ],
        ),
        if (maxZoom > minZoom)
          Slider(
            value: zoomLevel.clamp(minZoom, maxZoom).toDouble(),
            min: minZoom,
            max: maxZoom,
            onChanged: onChanged,
          ),
      ],
    );
  }
}

class _ZoomChip extends StatelessWidget {
  const _ZoomChip({
    required this.zoom,
    required this.selected,
    required this.onTap,
  });

  final double zoom;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = zoom == zoom.roundToDouble()
        ? '${zoom.toStringAsFixed(0)}x'
        : '${zoom.toStringAsFixed(1)}x';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white24 : Colors.black38,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.amber : Colors.white,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
