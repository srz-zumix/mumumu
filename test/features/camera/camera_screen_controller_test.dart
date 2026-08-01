import 'dart:ui' show Offset, Size;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mumumu/core/permissions/permission_service.dart';
import 'package:mumumu/core/preferences/settings_controller.dart';
import 'package:mumumu/features/camera/camera_screen_controller.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silent_camera/silent_camera.dart';

/// テスト用のプラットフォーム実装。
class FakeSilentCameraPlatform extends SilentCameraPlatform
    with MockPlatformInterfaceMixin {
  int captureCount = 0;
  CaptureOptions? lastOptions;
  FlashMode? lastFlashMode;
  bool released = false;
  SilentCameraException? captureError;

  @override
  Future<List<CameraDescription>> availableCameras() async =>
      const <CameraDescription>[
        CameraDescription(
          id: 'back',
          lensDirection: CameraLensDirection.back,
          sensorOrientation: 90,
          hasFlash: true,
        ),
        CameraDescription(
          id: 'front',
          lensDirection: CameraLensDirection.front,
          sensorOrientation: 270,
        ),
      ];

  @override
  Future<CameraInitializationResult> initialize({
    CameraLensDirection lensDirection = CameraLensDirection.back,
    CaptureResolution resolution = CaptureResolution.max,
    CaptureMode captureMode = CaptureMode.silentVideoFrame,
  }) async {
    return CameraInitializationResult(
      textureId: 1,
      previewSize: const Size(1080, 1920),
      minExposureOffset: -2,
      maxExposureOffset: 2,
      exposureOffsetStep: 0.1,
      description: CameraDescription(
        id: lensDirection == CameraLensDirection.back ? 'back' : 'front',
        lensDirection: lensDirection,
        sensorOrientation: 90,
        maxZoom: 8,
        hasFlash: lensDirection == CameraLensDirection.back,
      ),
    );
  }

  @override
  Future<CaptureResult> capture(CaptureOptions options) async {
    if (captureError != null) {
      throw captureError!;
    }
    captureCount++;
    lastOptions = options;
    return CaptureResult(
      filePath: '/tmp/IMG_00000001.jpg',
      width: 4032,
      height: 3024,
      capturedAt: DateTime(2024),
      fileName: 'IMG_00000001.jpg',
    );
  }

  @override
  Future<void> dispose() async {
    released = true;
  }

  @override
  Future<void> setFlashMode(FlashMode mode) async {
    lastFlashMode = mode;
  }

  @override
  Future<SilenceCapability> getSilenceCapability() async =>
      const SilenceCapability(
        isSilentCaptureSupported: true,
        isShutterSoundEnforcedByOs: false,
      );

  @override
  Future<void> pausePreview() async {}

  @override
  Future<void> resumePreview() async {}

  @override
  Future<void> setZoomLevel(double zoom) async {}

  @override
  Future<void> setFocusAndExposurePoint(Offset point) async {}

  @override
  Future<void> setFocusAndExposureLocked({required bool locked}) async {}

  @override
  Future<void> setExposureOffset(double offset) async {}

  @override
  Future<void> openInGallery(String identifier) async {}

  @override
  Future<bool> deleteFromGallery(String identifier) async => true;
}

/// テスト用の権限サービス。
class FakePermissionService implements PermissionService {
  FakePermissionService({
    this.camera = AppPermissionStatus.granted,
    this.photoLibrary = AppPermissionStatus.granted,
  });

  AppPermissionStatus camera;
  AppPermissionStatus photoLibrary;

  @override
  Future<PermissionSnapshot> check() async =>
      PermissionSnapshot(camera: camera, photoLibrary: photoLibrary);

  @override
  Future<AppPermissionStatus> requestCamera() async => camera;

  @override
  Future<AppPermissionStatus> requestPhotoLibrary() async => photoLibrary;

  @override
  Future<AppPermissionStatus> requestLocation() async =>
      AppPermissionStatus.granted;

  @override
  Future<AppPermissionStatus> requestMicrophone() async =>
      AppPermissionStatus.granted;

  @override
  Future<bool> openSettings() async => true;
}

Future<ProviderContainer> createContainer({
  required FakePermissionService permissions,
  Map<String, Object> initialValues = const <String, Object>{},
}) async {
  SharedPreferences.setMockInitialValues(initialValues);
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      sharedPreferencesProvider.overrideWithValue(prefs),
      permissionServiceProvider.overrideWithValue(permissions),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSilentCameraPlatform platform;

  setUp(() {
    platform = FakeSilentCameraPlatform();
    SilentCameraPlatform.instance = platform;
  });

  test('カメラ権限が許可されると初期化が完了する', () async {
    final ProviderContainer container = await createContainer(
      permissions: FakePermissionService(),
    );

    await container.read(cameraScreenProvider.notifier).start();

    final CameraScreenState state = container.read(cameraScreenProvider);
    expect(state.isReady, isTrue);
    expect(state.isInitializing, isFalse);
    expect(state.errorMessage, isNull);
    expect(state.canShoot, isTrue);
  });

  test('カメラ権限が拒否されるとエラーになり初期化しない', () async {
    final ProviderContainer container = await createContainer(
      permissions: FakePermissionService(
        camera: AppPermissionStatus.permanentlyDenied,
      ),
    );

    await container.read(cameraScreenProvider.notifier).start();

    final CameraScreenState state = container.read(cameraScreenProvider);
    expect(state.isReady, isFalse);
    expect(state.errorMessage, isNotNull);
    expect(state.canShoot, isFalse);
  });

  test('撮影すると設定値がキャプチャオプションへ反映される', () async {
    final ProviderContainer container = await createContainer(
      permissions: FakePermissionService(),
      initialValues: <String, Object>{
        'jpeg_quality': 85,
        'format': 'heic',
        'aspect_ratio': 'ratio1x1',
        'include_location': true,
      },
    );
    final CameraScreenController controller = container.read(
      cameraScreenProvider.notifier,
    );

    await controller.start();
    await controller.shoot();

    expect(platform.captureCount, 1);
    expect(platform.lastOptions?.saveToGallery, isTrue);
    expect(platform.lastOptions?.jpegQuality, 85);
    expect(platform.lastOptions?.format, CaptureFormat.heic);
    expect(platform.lastOptions?.aspectRatio, CaptureAspectRatio.ratio1x1);
    expect(platform.lastOptions?.includeLocation, isTrue);
    expect(container.read(cameraScreenProvider).lastCapture, isNotNull);
    expect(container.read(cameraScreenProvider).isCapturing, isFalse);
  });

  test('写真ライブラリ権限がないときは保存せず注意を表示する', () async {
    final ProviderContainer container = await createContainer(
      permissions: FakePermissionService(
        photoLibrary: AppPermissionStatus.denied,
      ),
    );
    final CameraScreenController controller = container.read(
      cameraScreenProvider.notifier,
    );

    await controller.start();
    await controller.shoot();

    expect(platform.lastOptions?.saveToGallery, isFalse);
    expect(container.read(cameraScreenProvider).errorMessage, isNotNull);
  });

  test('撮影に失敗するとエラーメッセージを保持する', () async {
    final ProviderContainer container = await createContainer(
      permissions: FakePermissionService(),
    );
    platform.captureError = const SilentCameraException(
      'capture_failed',
      '撮影に失敗しました。',
    );
    final CameraScreenController controller = container.read(
      cameraScreenProvider.notifier,
    );

    await controller.start();
    await controller.shoot();

    expect(container.read(cameraScreenProvider).isCapturing, isFalse);
    expect(container.read(cameraScreenProvider).errorMessage, '撮影に失敗しました。');
    expect(container.read(cameraScreenProvider).lastCapture, isNull);
  });

  test('フラッシュモードの変更は設定として永続化される', () async {
    final ProviderContainer container = await createContainer(
      permissions: FakePermissionService(),
    );
    final CameraScreenController controller = container.read(
      cameraScreenProvider.notifier,
    );

    await controller.start();
    await controller.setFlashMode(FlashMode.torch);

    expect(container.read(settingsProvider).flashMode, FlashMode.torch);
    expect(platform.lastFlashMode, FlashMode.torch);
  });

  test('停止するとカメラを解放する', () async {
    final ProviderContainer container = await createContainer(
      permissions: FakePermissionService(),
    );
    final CameraScreenController controller = container.read(
      cameraScreenProvider.notifier,
    );

    await controller.start();
    await controller.stop();

    expect(platform.released, isTrue);
    expect(container.read(cameraScreenProvider).isReady, isFalse);
  });
}
