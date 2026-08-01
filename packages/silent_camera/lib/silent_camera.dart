/// 無音（静音）キャプチャを提供するプラグイン。
///
/// 仕様書 4「技術方針」に基づき、ビデオフレームからの静止画切り出しを
/// iOS（AVFoundation）/ Android（CameraX）でネイティブ実装する。
library;

export 'src/models.dart';
export 'src/silent_camera_controller.dart';
export 'src/silent_camera_method_channel.dart';
export 'src/silent_camera_platform_interface.dart';
export 'src/silent_camera_preview.dart';
