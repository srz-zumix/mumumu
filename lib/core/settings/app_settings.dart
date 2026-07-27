import 'package:flutter/material.dart';
import 'package:silent_camera/silent_camera.dart';

/// 端末に保存されるアプリ設定。
@immutable
class AppSettings {
  const AppSettings({
    this.onboardingCompleted = false,
    this.gridEnabled = false,
    this.captureMode = CaptureMode.silent,
    this.photoFormat = PhotoFormat.jpeg,
    this.aspectRatio = AspectRatioPreset.ratio4x3,
    this.jpegQuality = 95,
    this.saveLocation = false,
    this.mirrorFrontCamera = false,
    this.tapToShoot = false,
    this.timerSeconds = 0,
    this.themeMode = ThemeMode.dark,
  });

  final bool onboardingCompleted;
  final bool gridEnabled;
  final CaptureMode captureMode;
  final PhotoFormat photoFormat;
  final AspectRatioPreset aspectRatio;
  final int jpegQuality;

  /// Exif へ位置情報を付与するか。
  final bool saveLocation;

  /// 前面カメラの画像を左右反転して保存するか。
  final bool mirrorFrontCamera;
  final bool tapToShoot;

  /// セルフタイマー秒数（0 は無効）。
  final int timerSeconds;
  final ThemeMode themeMode;

  AppSettings copyWith({
    bool? onboardingCompleted,
    bool? gridEnabled,
    CaptureMode? captureMode,
    PhotoFormat? photoFormat,
    AspectRatioPreset? aspectRatio,
    int? jpegQuality,
    bool? saveLocation,
    bool? mirrorFrontCamera,
    bool? tapToShoot,
    int? timerSeconds,
    ThemeMode? themeMode,
  }) {
    return AppSettings(
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      gridEnabled: gridEnabled ?? this.gridEnabled,
      captureMode: captureMode ?? this.captureMode,
      photoFormat: photoFormat ?? this.photoFormat,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      jpegQuality: jpegQuality ?? this.jpegQuality,
      saveLocation: saveLocation ?? this.saveLocation,
      mirrorFrontCamera: mirrorFrontCamera ?? this.mirrorFrontCamera,
      tapToShoot: tapToShoot ?? this.tapToShoot,
      timerSeconds: timerSeconds ?? this.timerSeconds,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}
