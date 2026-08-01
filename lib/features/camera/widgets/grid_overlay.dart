import 'package:flutter/material.dart';

/// 3 分割グリッドを描画するオーバーレイ。仕様書 5.1「グリッド表示」に対応する。
class GridOverlay extends StatelessWidget {
  /// 3 分割グリッドのオーバーレイを生成する。
  const GridOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(size: Size.infinite, painter: _GridPainter()),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = const Color(0x80FFFFFF)
      ..strokeWidth = 0.5;

    for (int i = 1; i < 3; i++) {
      final double dx = size.width * i / 3;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), paint);

      final double dy = size.height * i / 3;
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => false;
}
