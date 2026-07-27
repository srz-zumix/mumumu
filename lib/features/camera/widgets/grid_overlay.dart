import 'package:flutter/material.dart';

/// 3 分割グリッドのオーバーレイ。
class GridOverlay extends StatelessWidget {
  const GridOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _GridPainter(),
        size: Size.infinite,
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final Paint _paint = Paint()
    ..color = Colors.white.withValues(alpha: 0.4)
    ..strokeWidth = 0.5;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 1; i < 3; i++) {
      final dx = size.width * i / 3;
      final dy = size.height * i / 3;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), _paint);
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), _paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
