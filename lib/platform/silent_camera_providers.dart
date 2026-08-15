import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silent_camera/silent_camera.dart';

/// 無音カメラプラグインのコントローラを供給する。
///
/// 仕様書 4.1 の `lib/platform/`（Platform Channel ラッパー）に相当する。
final Provider<SilentCameraController> silentCameraControllerProvider =
    Provider<SilentCameraController>((Ref ref) {
      final SilentCameraController controller = SilentCameraController();
      ref.onDispose(controller.dispose);
      return controller;
    });

/// 端末の無音撮影対応状況を供給する。
///
/// 仕様書 2.3 のとおり、非対応時はアプリ内で明示するために使用する。
final FutureProvider<SilenceCapability> silenceCapabilityProvider =
    FutureProvider<SilenceCapability>(
      (Ref ref) =>
          ref.watch(silentCameraControllerProvider).getSilenceCapability(),
    );
