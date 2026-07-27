import 'package:flutter/material.dart';

/// mumumu のテーマ定義。
///
/// プレビューを妨げないよう、暗色ベースの落ち着いた配色を用いる。
abstract final class MumumuTheme {
  static const Color seed = Color(0xFF4F6D7A);

  static ThemeData light() => _base(Brightness.light);

  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor:
          brightness == Brightness.dark ? Colors.black : scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
      ),
    );
  }
}
