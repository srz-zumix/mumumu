import 'package:flutter/material.dart';
import 'package:silent_camera/silent_camera.dart';

import '../features/camera/camera_page.dart';
import '../features/onboarding/onboarding_page.dart';
import '../features/settings/settings_page.dart';
import '../features/viewer/viewer_page.dart';

/// アプリ内のルート名。
class AppRoutes {
  const AppRoutes._();

  /// オンボーディング画面。
  static const String onboarding = '/onboarding';

  /// カメラ画面（メイン）。
  static const String camera = '/camera';

  /// ビューア画面。
  static const String viewer = '/viewer';

  /// 設定画面。
  static const String settings = '/settings';
}

/// 名前付きルートを解決する。
///
/// 仕様書 6「画面仕様」の 4 画面を扱う。
Route<dynamic>? generateRoute(RouteSettings settings) {
  switch (settings.name) {
    case AppRoutes.onboarding:
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (BuildContext context) => const OnboardingPage(),
      );

    case AppRoutes.camera:
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (BuildContext context) => const CameraPage(),
      );

    case AppRoutes.viewer:
      final Object? argument = settings.arguments;
      if (argument is! CaptureResult) {
        return null;
      }
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (BuildContext context) => ViewerPage(capture: argument),
      );

    case AppRoutes.settings:
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (BuildContext context) => const SettingsPage(),
      );

    default:
      return null;
  }
}
