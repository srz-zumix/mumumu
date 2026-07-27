import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silent_camera/silent_camera.dart';

import 'app_settings.dart';

/// `main` で上書きして提供される `SharedPreferences`。
final Provider<SharedPreferences> sharedPreferencesProvider =
    Provider<SharedPreferences>(
  (Ref ref) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main().',
  ),
);

/// アプリ設定の読み書きを担う。
final NotifierProvider<SettingsController, AppSettings> settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

/// 設定値を `SharedPreferences` に永続化するコントローラ。
class SettingsController extends Notifier<AppSettings> {
  static const String _keyOnboardingCompleted = 'onboarding_completed';
  static const String _keyGridEnabled = 'grid_enabled';
  static const String _keyCaptureMode = 'capture_mode';
  static const String _keyPhotoFormat = 'photo_format';
  static const String _keyAspectRatio = 'aspect_ratio';
  static const String _keyJpegQuality = 'jpeg_quality';
  static const String _keySaveLocation = 'save_location';
  static const String _keyMirrorFrontCamera = 'mirror_front_camera';
  static const String _keyTapToShoot = 'tap_to_shoot';
  static const String _keyTimerSeconds = 'timer_seconds';
  static const String _keyThemeMode = 'theme_mode';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  AppSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    const defaults = AppSettings();
    return AppSettings(
      onboardingCompleted: prefs.getBool(_keyOnboardingCompleted) ??
          defaults.onboardingCompleted,
      gridEnabled: prefs.getBool(_keyGridEnabled) ?? defaults.gridEnabled,
      captureMode: _byName(
        CaptureMode.values,
        prefs.getString(_keyCaptureMode),
        defaults.captureMode,
      ),
      photoFormat: _byName(
        PhotoFormat.values,
        prefs.getString(_keyPhotoFormat),
        defaults.photoFormat,
      ),
      aspectRatio: _byName(
        AspectRatioPreset.values,
        prefs.getString(_keyAspectRatio),
        defaults.aspectRatio,
      ),
      jpegQuality: prefs.getInt(_keyJpegQuality) ?? defaults.jpegQuality,
      saveLocation: prefs.getBool(_keySaveLocation) ?? defaults.saveLocation,
      mirrorFrontCamera:
          prefs.getBool(_keyMirrorFrontCamera) ?? defaults.mirrorFrontCamera,
      tapToShoot: prefs.getBool(_keyTapToShoot) ?? defaults.tapToShoot,
      timerSeconds: prefs.getInt(_keyTimerSeconds) ?? defaults.timerSeconds,
      themeMode: _byName(
        ThemeMode.values,
        prefs.getString(_keyThemeMode),
        defaults.themeMode,
      ),
    );
  }

  /// オンボーディング完了を記録する。
  Future<void> completeOnboarding() async {
    state = state.copyWith(onboardingCompleted: true);
    await _prefs.setBool(_keyOnboardingCompleted, true);
  }

  Future<void> setGridEnabled({required bool enabled}) async {
    state = state.copyWith(gridEnabled: enabled);
    await _prefs.setBool(_keyGridEnabled, enabled);
  }

  Future<void> setCaptureMode(CaptureMode mode) async {
    state = state.copyWith(captureMode: mode);
    await _prefs.setString(_keyCaptureMode, mode.name);
  }

  Future<void> setPhotoFormat(PhotoFormat format) async {
    state = state.copyWith(photoFormat: format);
    await _prefs.setString(_keyPhotoFormat, format.name);
  }

  Future<void> setAspectRatio(AspectRatioPreset ratio) async {
    state = state.copyWith(aspectRatio: ratio);
    await _prefs.setString(_keyAspectRatio, ratio.name);
  }

  Future<void> setJpegQuality(int quality) async {
    final clamped = quality.clamp(50, 100).toInt();
    state = state.copyWith(jpegQuality: clamped);
    await _prefs.setInt(_keyJpegQuality, clamped);
  }

  Future<void> setSaveLocation({required bool enabled}) async {
    state = state.copyWith(saveLocation: enabled);
    await _prefs.setBool(_keySaveLocation, enabled);
  }

  Future<void> setMirrorFrontCamera({required bool enabled}) async {
    state = state.copyWith(mirrorFrontCamera: enabled);
    await _prefs.setBool(_keyMirrorFrontCamera, enabled);
  }

  Future<void> setTapToShoot({required bool enabled}) async {
    state = state.copyWith(tapToShoot: enabled);
    await _prefs.setBool(_keyTapToShoot, enabled);
  }

  Future<void> setTimerSeconds(int seconds) async {
    state = state.copyWith(timerSeconds: seconds);
    await _prefs.setInt(_keyTimerSeconds, seconds);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _prefs.setString(_keyThemeMode, mode.name);
  }

  static T _byName<T extends Enum>(List<T> values, String? name, T fallback) {
    for (final value in values) {
      if (value.name == name) {
        return value;
      }
    }
    return fallback;
  }
}
