import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/settings/settings_controller.dart';
import '../features/camera/camera_page.dart';
import '../features/onboarding/onboarding_page.dart';
import '../features/settings/settings_page.dart';
import 'theme.dart';

/// mumumu アプリのルートウィジェット。
class MumumuApp extends ConsumerWidget {
  const MumumuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return MaterialApp(
      title: 'mumumu',
      debugShowCheckedModeBanner: false,
      theme: MumumuTheme.light(),
      darkTheme: MumumuTheme.dark(),
      themeMode: settings.themeMode,
      home: settings.onboardingCompleted
          ? const CameraPage()
          : const OnboardingPage(),
      routes: <String, WidgetBuilder>{
        CameraPage.routeName: (_) => const CameraPage(),
        SettingsPage.routeName: (_) => const SettingsPage(),
        OnboardingPage.routeName: (_) => const OnboardingPage(),
      },
    );
  }
}
