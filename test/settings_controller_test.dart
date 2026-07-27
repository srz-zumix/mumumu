import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mumumu/core/settings/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silent_camera/silent_camera.dart';

Future<ProviderContainer> _createContainer([
  Map<String, Object> initialValues = const <String, Object>{},
]) async {
  SharedPreferences.setMockInitialValues(initialValues);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: <Override>[
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('既定値は無音モード・オンボーディング未完了', () async {
    final container = await _createContainer();
    final settings = container.read(settingsProvider);
    expect(settings.onboardingCompleted, isFalse);
    expect(settings.captureMode, CaptureMode.silent);
    expect(settings.aspectRatio, AspectRatioPreset.ratio4x3);
    expect(settings.gridEnabled, isFalse);
    expect(settings.timerSeconds, 0);
  });

  test('保存済みの設定を復元する', () async {
    final container = await _createContainer(<String, Object>{
      'flutter.onboarding_completed': true,
      'flutter.capture_mode': 'photo',
      'flutter.aspect_ratio': 'ratio16x9',
      'flutter.theme_mode': 'light',
      'flutter.timer_seconds': 5,
    });
    final settings = container.read(settingsProvider);
    expect(settings.onboardingCompleted, isTrue);
    expect(settings.captureMode, CaptureMode.photo);
    expect(settings.aspectRatio, AspectRatioPreset.ratio16x9);
    expect(settings.themeMode, ThemeMode.light);
    expect(settings.timerSeconds, 5);
  });

  test('不正な値は既定値へフォールバックする', () async {
    final container = await _createContainer(<String, Object>{
      'flutter.capture_mode': 'unknown',
    });
    expect(container.read(settingsProvider).captureMode, CaptureMode.silent);
  });

  test('変更は永続化される', () async {
    final container = await _createContainer();
    final controller = container.read(settingsProvider.notifier);
    await controller.completeOnboarding();
    await controller.setGridEnabled(enabled: true);
    await controller.setTimerSeconds(10);
    await controller.setJpegQuality(120);

    final settings = container.read(settingsProvider);
    expect(settings.onboardingCompleted, isTrue);
    expect(settings.gridEnabled, isTrue);
    expect(settings.timerSeconds, 10);
    expect(settings.jpegQuality, 100);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_completed'), isTrue);
    expect(prefs.getInt('timer_seconds'), 10);
  });
}
