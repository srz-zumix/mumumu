import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/preferences/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 仕様書 3 のとおり縦向きを主体とし、横向きにも対応する。
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  final SharedPreferences preferences = await SharedPreferences.getInstance();
  await _clearCaptureCache();

  runApp(
    ProviderScope(
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(preferences),
      ],
      child: const MumumuApp(),
    ),
  );
}

/// 前回起動時のキャプチャキャッシュを削除する。
///
/// 仕様書 7 のとおり、アプリ内に画像を隠し持たないようにするため、
/// ビューア表示用の一時ファイルは起動のたびに破棄する。
Future<void> _clearCaptureCache() async {
  try {
    final Directory directory = Directory(
      '${Directory.systemTemp.path}/mumumu_captures',
    );
    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
  } on FileSystemException {
    // キャッシュの削除に失敗しても起動は継続する。
  }
}
