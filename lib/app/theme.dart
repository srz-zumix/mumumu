import 'package:flutter/material.dart';

/// アプリのテーマ定義。
///
/// 仕様書 12「未決事項」のとおりブランドカラーは未確定のため、
/// 撮影の妨げにならない落ち着いた配色を暫定値として用いる。
class AppTheme {
  const AppTheme._();

  /// 暫定のブランドカラー。
  static const Color seedColor = Color(0xFF4A6572);

  /// ライトテーマ。
  static ThemeData get light => _build(Brightness.light);

  /// ダークテーマ。
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
      ),
    );
  }

  /// カメラ画面で使う配色。
  ///
  /// プレビューの視認性を保つため、常に暗い背景と白い前景を用いる。
  static const Color cameraBackground = Color(0xFF000000);

  /// カメラ画面の前景色。
  static const Color cameraForeground = Color(0xFFFFFFFF);

  /// カメラ画面のオーバーレイ背景色。
  static const Color cameraOverlay = Color(0x66000000);
}
