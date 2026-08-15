import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mumumu/core/preferences/app_settings.dart';
import 'package:silent_camera/silent_camera.dart';

void main() {
  group('AppSettings', () {
    test('既定値は仕様書のプライバシー既定に従う', () {
      const AppSettings settings = AppSettings();

      expect(settings.onboardingCompleted, isFalse);
      // 位置情報の付与は既定で無効（仕様書 8）。
      expect(settings.includeLocation, isFalse);
      expect(settings.captureMode, CaptureMode.silentVideoFrame);
      expect(settings.format, CaptureFormat.jpeg);
      expect(settings.selfTimer, SelfTimer.off);
      expect(settings.shutterMethod, ShutterMethod.button);
    });

    test('toCaptureOptions は設定値を引き継ぐ', () {
      const AppSettings settings = AppSettings(
        format: CaptureFormat.heic,
        jpegQuality: 80,
        aspectRatio: CaptureAspectRatio.ratio16x9,
        includeLocation: true,
        mirrorFrontCamera: true,
      );

      final CaptureOptions options = settings.toCaptureOptions();

      expect(options.format, CaptureFormat.heic);
      expect(options.jpegQuality, 80);
      expect(options.aspectRatio, CaptureAspectRatio.ratio16x9);
      expect(options.includeLocation, isTrue);
      expect(options.mirrorFrontCamera, isTrue);
      expect(options.albumName, 'mumumu');
    });

    test('copyWith は指定した値のみ更新する', () {
      const AppSettings settings = AppSettings();
      final AppSettings updated = settings.copyWith(themeMode: ThemeMode.dark);

      expect(updated.themeMode, ThemeMode.dark);
      expect(updated.gridEnabled, settings.gridEnabled);
      expect(updated, isNot(settings));
      expect(updated.copyWith(themeMode: ThemeMode.system), settings);
    });
  });

  group('SelfTimer', () {
    test('秒数が定義どおりである', () {
      expect(SelfTimer.off.seconds, 0);
      expect(SelfTimer.seconds3.seconds, 3);
      expect(SelfTimer.seconds5.seconds, 5);
      expect(SelfTimer.seconds10.seconds, 10);
    });
  });

  group('CaptureAspectRatio', () {
    test('比率が定義どおりである', () {
      expect(CaptureAspectRatio.ratio4x3.value, closeTo(4 / 3, 1e-9));
      expect(CaptureAspectRatio.ratio16x9.value, closeTo(16 / 9, 1e-9));
      expect(CaptureAspectRatio.ratio1x1.value, 1.0);
    });
  });
}
