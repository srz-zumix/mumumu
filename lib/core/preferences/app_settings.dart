import 'package:flutter/material.dart';
import 'package:silent_camera/silent_camera.dart';

/// シャッター操作の方法。仕様書 5.2 / 6-4 に対応する。
enum ShutterMethod {
  /// シャッターボタンのみ。
  button,

  /// 音量ボタンでも撮影する。
  volumeKey,

  /// 画面全体のタップでも撮影する。
  tapAnywhere,
}

/// シャッター操作方法の表示ラベル。
extension ShutterMethodX on ShutterMethod {
  /// 設定画面で表示するラベル。
  String get label => switch (this) {
    ShutterMethod.button => 'シャッターボタンのみ',
    ShutterMethod.volumeKey => '音量ボタンでも撮影',
    ShutterMethod.tapAnywhere => '画面タップでも撮影',
  };
}

/// セルフタイマーの秒数。仕様書 5.2 に対応する。
enum SelfTimer {
  /// タイマーなし。
  off(0),

  /// 3 秒。
  seconds3(3),

  /// 5 秒。
  seconds5(5),

  /// 10 秒。
  seconds10(10);

  const SelfTimer(this.seconds);

  /// 待機秒数。
  final int seconds;

  /// 設定画面・カメラ画面で表示するラベル。
  String get label => seconds == 0 ? 'OFF' : '${seconds}s';
}

/// アプリの永続設定。仕様書 6-4「設定画面」に対応する。
@immutable
class AppSettings {
  /// アプリの永続設定を生成する。
  const AppSettings({
    this.onboardingCompleted = false,
    this.themeMode = ThemeMode.system,
    this.captureMode = CaptureMode.silentVideoFrame,
    this.resolution = CaptureResolution.max,
    this.aspectRatio = CaptureAspectRatio.ratio4x3,
    this.format = CaptureFormat.jpeg,
    this.jpegQuality = 95,
    this.includeLocation = false,
    this.mirrorFrontCamera = false,
    this.gridEnabled = false,
    this.shutterMethod = ShutterMethod.button,
    this.selfTimer = SelfTimer.off,
    this.flashMode = FlashMode.off,
  });

  /// オンボーディングを完了したかどうか。
  final bool onboardingCompleted;

  /// テーマ設定。
  final ThemeMode themeMode;

  /// キャプチャ方式（静音 / 写真）。
  final CaptureMode captureMode;

  /// 解像度プリセット。
  final CaptureResolution resolution;

  /// アスペクト比。
  final CaptureAspectRatio aspectRatio;

  /// 保存フォーマット。
  final CaptureFormat format;

  /// JPEG 品質。
  final int jpegQuality;

  /// Exif に位置情報を付与するかどうか。
  final bool includeLocation;

  /// 前面カメラを鏡像で保存するかどうか。
  final bool mirrorFrontCamera;

  /// 3 分割グリッドを表示するかどうか。
  final bool gridEnabled;

  /// シャッター操作の方法。
  final ShutterMethod shutterMethod;

  /// セルフタイマー。
  final SelfTimer selfTimer;

  /// フラッシュモード。
  final FlashMode flashMode;

  /// 現在の設定から撮影オプションを組み立てる。
  CaptureOptions toCaptureOptions() => CaptureOptions(
    jpegQuality: jpegQuality,
    format: format,
    aspectRatio: aspectRatio,
    mirrorFrontCamera: mirrorFrontCamera,
    includeLocation: includeLocation,
  );

  /// 一部の値を差し替えた設定を返す。
  AppSettings copyWith({
    bool? onboardingCompleted,
    ThemeMode? themeMode,
    CaptureMode? captureMode,
    CaptureResolution? resolution,
    CaptureAspectRatio? aspectRatio,
    CaptureFormat? format,
    int? jpegQuality,
    bool? includeLocation,
    bool? mirrorFrontCamera,
    bool? gridEnabled,
    ShutterMethod? shutterMethod,
    SelfTimer? selfTimer,
    FlashMode? flashMode,
  }) {
    return AppSettings(
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      themeMode: themeMode ?? this.themeMode,
      captureMode: captureMode ?? this.captureMode,
      resolution: resolution ?? this.resolution,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      format: format ?? this.format,
      jpegQuality: jpegQuality ?? this.jpegQuality,
      includeLocation: includeLocation ?? this.includeLocation,
      mirrorFrontCamera: mirrorFrontCamera ?? this.mirrorFrontCamera,
      gridEnabled: gridEnabled ?? this.gridEnabled,
      shutterMethod: shutterMethod ?? this.shutterMethod,
      selfTimer: selfTimer ?? this.selfTimer,
      flashMode: flashMode ?? this.flashMode,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.onboardingCompleted == onboardingCompleted &&
      other.themeMode == themeMode &&
      other.captureMode == captureMode &&
      other.resolution == resolution &&
      other.aspectRatio == aspectRatio &&
      other.format == format &&
      other.jpegQuality == jpegQuality &&
      other.includeLocation == includeLocation &&
      other.mirrorFrontCamera == mirrorFrontCamera &&
      other.gridEnabled == gridEnabled &&
      other.shutterMethod == shutterMethod &&
      other.selfTimer == selfTimer &&
      other.flashMode == flashMode;

  @override
  int get hashCode => Object.hash(
    onboardingCompleted,
    themeMode,
    captureMode,
    resolution,
    aspectRatio,
    format,
    jpegQuality,
    includeLocation,
    mirrorFrontCamera,
    gridEnabled,
    shutterMethod,
    selfTimer,
    flashMode,
  );
}
