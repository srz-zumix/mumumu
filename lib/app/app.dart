import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/preferences/app_settings.dart';
import '../core/preferences/settings_controller.dart';
import 'router.dart';
import 'theme.dart';

/// アプリのルートウィジェット。
class MumumuApp extends ConsumerWidget {
  /// アプリのルートウィジェットを生成する。
  const MumumuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings settings = ref.watch(settingsProvider);

    return MaterialApp(
      // ストア審査を考慮し「無音」ではなく「静かに撮れるカメラ」と表現する（仕様書 2.1）。
      title: 'mumumu',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.themeMode,
      onGenerateRoute: generateRoute,
      initialRoute: settings.onboardingCompleted
          ? AppRoutes.camera
          : AppRoutes.onboarding,
    );
  }
}
