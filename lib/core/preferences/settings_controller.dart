import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silent_camera/silent_camera.dart';

import 'app_settings.dart';

/// `SharedPreferences` のインスタンスを供給する。
///
/// `main()` で読み込み済みのインスタンスを [ProviderScope.overrides] で差し込む。
final Provider<SharedPreferences> sharedPreferencesProvider =
    Provider<SharedPreferences>(
      (Ref ref) => throw UnimplementedError(
        'sharedPreferencesProvider は main() で override してください。',
      ),
    );

/// アプリ設定を保持・永続化する。
final NotifierProvider<SettingsController, AppSettings> settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

/// 設定値の読み書きを担当するコントローラ。
///
/// 仕様書 4.2 のとおり、永続化は `shared_preferences` の設定値のみとする。
class SettingsController extends Notifier<AppSettings> {
  static const String _keyOnboardingCompleted = 'onboarding_completed';
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyCaptureMode = 'capture_mode';
  static const String _keyResolution = 'resolution';
  static const String _keyAspectRatio = 'aspect_ratio';
  static const String _keyFormat = 'format';
  static const String _keyJpegQuality = 'jpeg_quality';
  static const String _keyIncludeLocation = 'include_location';
  static const String _keyMirrorFrontCamera = 'mirror_front_camera';
  static const String _keyGridEnabled = 'grid_enabled';
  static const String _keyShutterMethod = 'shutter_method';
  static const String _keySelfTimer = 'self_timer';
  static const String _keyFlashMode = 'flash_mode';

  late final SharedPreferences _prefs;

  @override
  AppSettings build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    return _read();
  }

  AppSettings _read() {
    return AppSettings(
      onboardingCompleted: _prefs.getBool(_keyOnboardingCompleted) ?? false,
      themeMode: _enumOf(
        ThemeMode.values,
        _prefs.getString(_keyThemeMode),
        ThemeMode.system,
      ),
      captureMode: _enumOf(
        CaptureMode.values,
        _prefs.getString(_keyCaptureMode),
        CaptureMode.silentVideoFrame,
      ),
      resolution: _enumOf(
        CaptureResolution.values,
        _prefs.getString(_keyResolution),
        CaptureResolution.max,
      ),
      aspectRatio: _enumOf(
        CaptureAspectRatio.values,
        _prefs.getString(_keyAspectRatio),
        CaptureAspectRatio.ratio4x3,
      ),
      format: _enumOf(
        CaptureFormat.values,
        _prefs.getString(_keyFormat),
        CaptureFormat.jpeg,
      ),
      jpegQuality: _prefs.getInt(_keyJpegQuality) ?? 95,
      includeLocation: _prefs.getBool(_keyIncludeLocation) ?? false,
      mirrorFrontCamera: _prefs.getBool(_keyMirrorFrontCamera) ?? false,
      gridEnabled: _prefs.getBool(_keyGridEnabled) ?? false,
      shutterMethod: _enumOf(
        ShutterMethod.values,
        _prefs.getString(_keyShutterMethod),
        ShutterMethod.button,
      ),
      selfTimer: _enumOf(
        SelfTimer.values,
        _prefs.getString(_keySelfTimer),
        SelfTimer.off,
      ),
      flashMode: _enumOf(
        FlashMode.values,
        _prefs.getString(_keyFlashMode),
        FlashMode.off,
      ),
    );
  }

  static T _enumOf<T extends Enum>(List<T> values, String? name, T fallback) {
    if (name == null) {
      return fallback;
    }
    for (final T value in values) {
      if (value.name == name) {
        return value;
      }
    }
    return fallback;
  }

  /// オンボーディングの完了状態を保存する。
  Future<void> setOnboardingCompleted({required bool completed}) async {
    state = state.copyWith(onboardingCompleted: completed);
    await _prefs.setBool(_keyOnboardingCompleted, completed);
  }

  /// テーマを設定する。
  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _prefs.setString(_keyThemeMode, mode.name);
  }

  /// キャプチャ方式を設定する。
  Future<void> setCaptureMode(CaptureMode mode) async {
    state = state.copyWith(captureMode: mode);
    await _prefs.setString(_keyCaptureMode, mode.name);
  }

  /// 解像度を設定する。
  Future<void> setResolution(CaptureResolution resolution) async {
    state = state.copyWith(resolution: resolution);
    await _prefs.setString(_keyResolution, resolution.name);
  }

  /// アスペクト比を設定する。
  Future<void> setAspectRatio(CaptureAspectRatio ratio) async {
    state = state.copyWith(aspectRatio: ratio);
    await _prefs.setString(_keyAspectRatio, ratio.name);
  }

  /// 保存フォーマットを設定する。
  Future<void> setFormat(CaptureFormat format) async {
    state = state.copyWith(format: format);
    await _prefs.setString(_keyFormat, format.name);
  }

  /// JPEG 品質を設定する。
  Future<void> setJpegQuality(int quality) async {
    final int clamped = quality.clamp(1, 100);
    state = state.copyWith(jpegQuality: clamped);
    await _prefs.setInt(_keyJpegQuality, clamped);
  }

  /// 位置情報の付与を設定する。
  Future<void> setIncludeLocation({required bool enabled}) async {
    state = state.copyWith(includeLocation: enabled);
    await _prefs.setBool(_keyIncludeLocation, enabled);
  }

  /// 前面カメラのミラー保存を設定する。
  Future<void> setMirrorFrontCamera({required bool enabled}) async {
    state = state.copyWith(mirrorFrontCamera: enabled);
    await _prefs.setBool(_keyMirrorFrontCamera, enabled);
  }

  /// グリッド表示を設定する。
  Future<void> setGridEnabled({required bool enabled}) async {
    state = state.copyWith(gridEnabled: enabled);
    await _prefs.setBool(_keyGridEnabled, enabled);
  }

  /// シャッター操作方法を設定する。
  Future<void> setShutterMethod(ShutterMethod method) async {
    state = state.copyWith(shutterMethod: method);
    await _prefs.setString(_keyShutterMethod, method.name);
  }

  /// セルフタイマーを設定する。
  Future<void> setSelfTimer(SelfTimer timer) async {
    state = state.copyWith(selfTimer: timer);
    await _prefs.setString(_keySelfTimer, timer.name);
  }

  /// フラッシュモードを設定する。
  Future<void> setFlashMode(FlashMode mode) async {
    state = state.copyWith(flashMode: mode);
    await _prefs.setString(_keyFlashMode, mode.name);
  }
}
