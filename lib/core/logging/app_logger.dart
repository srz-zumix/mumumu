import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// アプリ内ロギング。
///
/// 仕様書 8「プライバシーポリシー方針」に従い、端末外へは一切送信しない。
/// リリースビルドでは何も出力しない。
class AppLogger {
  /// 名前付きロガーを生成する。
  const AppLogger(this.name);

  /// ログの出力元を示す名前。
  final String name;

  /// デバッグ情報を出力する。
  void debug(String message) => _log(message);

  /// エラーを出力する。
  void error(String message, [Object? error, StackTrace? stackTrace]) =>
      _log(message, error: error, stackTrace: stackTrace);

  void _log(String message, {Object? error, StackTrace? stackTrace}) {
    if (!kDebugMode) {
      return;
    }
    developer.log(
      message,
      name: 'mumumu.$name',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
