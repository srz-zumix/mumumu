import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'models.dart';
import 'silent_camera_platform_interface.dart';

/// MethodChannel を用いた [SilentCameraPlatform] の実装。
class MethodChannelSilentCamera extends SilentCameraPlatform {
  /// プラグインが使用するメソッドチャネル。
  @visibleForTesting
  final MethodChannel methodChannel = const MethodChannel(
    'dev.zumix.mumumu/silent_camera',
  );

  @override
  Future<SilenceCapability> getSilenceCapability() async {
    final Map<Object?, Object?> result = await _invokeMap(
      'getSilenceCapability',
    );
    return SilenceCapability.fromMap(result);
  }

  @override
  Future<List<CameraDescription>> availableCameras() async {
    final List<Object?>? result = await methodChannel
        .invokeMethod<List<Object?>>('availableCameras');
    if (result == null) {
      return const <CameraDescription>[];
    }
    return result
        .cast<Map<Object?, Object?>>()
        .map(CameraDescription.fromMap)
        .toList(growable: false);
  }

  @override
  Future<CameraInitializationResult> initialize({
    required CameraLensDirection lensDirection,
    required CaptureResolution resolution,
    required CaptureMode captureMode,
  }) async {
    final Map<Object?, Object?> result =
        await _invokeMap('initialize', <String, Object?>{
          'lensDirection': lensDirection.name,
          'resolution': resolution.name,
          'captureMode': captureMode.name,
        });
    return CameraInitializationResult.fromMap(result);
  }

  @override
  Future<void> dispose() => _invoke('dispose');

  @override
  Future<void> pausePreview() => _invoke('pausePreview');

  @override
  Future<void> resumePreview() => _invoke('resumePreview');

  @override
  Future<CaptureResult> capture(CaptureOptions options) async {
    final Map<Object?, Object?> result = await _invokeMap(
      'capture',
      options.toMap(),
    );
    return CaptureResult.fromMap(result);
  }

  @override
  Future<void> setZoomLevel(double zoom) =>
      _invoke('setZoomLevel', <String, Object?>{'zoom': zoom});

  @override
  Future<void> setFocusAndExposurePoint(Offset point) => _invoke(
    'setFocusAndExposurePoint',
    <String, Object?>{'x': point.dx, 'y': point.dy},
  );

  @override
  Future<void> setFocusAndExposureLocked({required bool locked}) =>
      _invoke('setFocusAndExposureLocked', <String, Object?>{'locked': locked});

  @override
  Future<void> setExposureOffset(double offset) =>
      _invoke('setExposureOffset', <String, Object?>{'offset': offset});

  @override
  Future<void> setFlashMode(FlashMode mode) =>
      _invoke('setFlashMode', <String, Object?>{'mode': mode.name});

  @override
  Future<void> openInGallery(String galleryUri) =>
      _invoke('openInGallery', <String, Object?>{'uri': galleryUri});

  @override
  Future<bool> deleteFromGallery(String galleryUri) async {
    try {
      final bool? deleted = await methodChannel.invokeMethod<bool>(
        'deleteFromGallery',
        <String, Object?>{'uri': galleryUri},
      );
      return deleted ?? false;
    } on PlatformException catch (e) {
      throw SilentCameraException(e.code, e.message ?? '');
    }
  }

  Future<void> _invoke(String method, [Map<String, Object?>? arguments]) async {
    try {
      await methodChannel.invokeMethod<void>(method, arguments);
    } on PlatformException catch (e) {
      throw SilentCameraException(e.code, e.message ?? '');
    }
  }

  Future<Map<Object?, Object?>> _invokeMap(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    try {
      final Map<Object?, Object?>? result = await methodChannel
          .invokeMethod<Map<Object?, Object?>>(method, arguments);
      if (result == null) {
        throw SilentCameraException('null_result', '$method から結果が返りませんでした。');
      }
      return result;
    } on PlatformException catch (e) {
      throw SilentCameraException(e.code, e.message ?? '');
    }
  }
}
