import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mumumu/core/preferences/app_settings.dart';
import 'package:mumumu/core/preferences/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silent_camera/silent_camera.dart';

Future<ProviderContainer> createContainer(
  Map<String, Object> initialValues,
) async {
  SharedPreferences.setMockInitialValues(initialValues);
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('保存済みの値を読み込む', () async {
    final ProviderContainer container = await createContainer(<String, Object>{
      'onboarding_completed': true,
      'theme_mode': 'dark',
      'capture_mode': 'photo',
      'jpeg_quality': 70,
      'self_timer': 'seconds5',
    });

    final AppSettings settings = container.read(settingsProvider);

    expect(settings.onboardingCompleted, isTrue);
    expect(settings.themeMode, ThemeMode.dark);
    expect(settings.captureMode, CaptureMode.photo);
    expect(settings.jpegQuality, 70);
    expect(settings.selfTimer, SelfTimer.seconds5);
  });

  test('未知の値は既定値にフォールバックする', () async {
    final ProviderContainer container = await createContainer(<String, Object>{
      'theme_mode': 'unknown',
      'format': 'webp',
    });

    final AppSettings settings = container.read(settingsProvider);

    expect(settings.themeMode, ThemeMode.system);
    expect(settings.format, CaptureFormat.jpeg);
  });

  test('設定変更が状態と永続化の双方に反映される', () async {
    final ProviderContainer container = await createContainer(
      const <String, Object>{},
    );
    final SettingsController controller = container.read(
      settingsProvider.notifier,
    );

    await controller.setThemeMode(ThemeMode.light);
    await controller.setIncludeLocation(enabled: true);
    await controller.setSelfTimer(SelfTimer.seconds10);
    await controller.setFlashMode(FlashMode.auto);

    expect(container.read(settingsProvider).themeMode, ThemeMode.light);
    expect(container.read(settingsProvider).includeLocation, isTrue);
    expect(container.read(settingsProvider).selfTimer, SelfTimer.seconds10);
    expect(container.read(settingsProvider).flashMode, FlashMode.auto);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_mode'), 'light');
    expect(prefs.getBool('include_location'), isTrue);
    expect(prefs.getString('self_timer'), 'seconds10');
    expect(prefs.getString('flash_mode'), 'auto');
  });

  test('JPEG 品質は 1〜100 に丸められる', () async {
    final ProviderContainer container = await createContainer(
      const <String, Object>{},
    );
    final SettingsController controller = container.read(
      settingsProvider.notifier,
    );

    await controller.setJpegQuality(150);
    expect(container.read(settingsProvider).jpegQuality, 100);

    await controller.setJpegQuality(0);
    expect(container.read(settingsProvider).jpegQuality, 1);
  });
}
