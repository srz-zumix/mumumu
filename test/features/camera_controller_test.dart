import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mumumu/core/permissions.dart';
import 'package:mumumu/core/settings/settings_controller.dart';
import 'package:mumumu/features/camera/camera_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silent_camera/silent_camera.dart';

class _FakePermissionService implements PermissionService {
  _FakePermissionService(this.outcome);

  final PermissionOutcome outcome;

  @override
  Future<bool> hasCapturePermissions() async =>
      outcome == PermissionOutcome.granted;

  @override
  Future<bool> openSettings() async => true;

  @override
  Future<PermissionOutcome> requestCapturePermissions() async => outcome;

  @override
  Future<PermissionOutcome> requestMicrophonePermission() async => outcome;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dev.srzzumix.mumumu/silent_camera');
  final List<MethodCall> calls = <MethodCall>[];

  Future<ProviderContainer> createContainer({
    PermissionOutcome outcome = PermissionOutcome.granted,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
        permissionServiceProvider
            .overrideWithValue(_FakePermissionService(outcome)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      calls.add(call);
      switch (call.method) {
        case 'availableCameras':
          return <Object?>[
            <Object?, Object?>{
              'id': '0',
              'lensDirection': 'back',
              'minZoom': 1.0,
              'maxZoom': 4.0,
              'zoomPresets': <Object?>[1.0, 2.0],
            },
          ];
        case 'silenceCapability':
          return <Object?, Object?>{
            'isSilent': false,
            'deviceModel': 'Test Device',
            'reason': 'テスト用',
          };
        case 'initialize':
          return <Object?, Object?>{
            'textureId': 1,
            'previewWidth': 1440.0,
            'previewHeight': 1080.0,
            'captureMode': 'silent',
            'minExposureOffset': -2.0,
            'maxExposureOffset': 2.0,
            'camera': <Object?, Object?>{
              'id': '0',
              'lensDirection': 'back',
              'minZoom': 1.0,
              'maxZoom': 4.0,
              'zoomPresets': <Object?>[1.0, 2.0],
            },
          };
        case 'capture':
          return <Object?, Object?>{
            'uri': 'content://media/1',
            'filePath': '/tmp/IMG.jpg',
            'width': 1440,
            'height': 1080,
            'capturedAt': 1767229261000,
          };
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('権限が許可されるとセッションを開始する', () async {
    final container = await createContainer();
    await container.read(cameraControllerProvider.notifier).initialize();

    final state = container.read(cameraControllerProvider);
    expect(state.isReady, isTrue);
    expect(state.permissionOutcome, PermissionOutcome.granted);
    expect(state.capability?.isSilent, isFalse);
    expect(state.session?.textureId, 1);
  });

  test('権限が拒否されるとセッションを開始しない', () async {
    final container = await createContainer(outcome: PermissionOutcome.denied);
    await container.read(cameraControllerProvider.notifier).initialize();

    final state = container.read(cameraControllerProvider);
    expect(state.isReady, isFalse);
    expect(state.permissionOutcome, PermissionOutcome.denied);
    expect(
      calls.where((MethodCall call) => call.method == 'initialize'),
      isEmpty,
    );
  });

  test('撮影結果が直近のサムネイルになる', () async {
    final container = await createContainer();
    final controller = container.read(cameraControllerProvider.notifier);
    await controller.initialize();
    final result = await controller.capture();

    expect(result?.uri, 'content://media/1');
    expect(container.read(cameraControllerProvider).lastCapture, isNotNull);
    expect(container.read(cameraControllerProvider).isCapturing, isFalse);
  });

  test('ズームはカメラの範囲に丸められる', () async {
    final container = await createContainer();
    final controller = container.read(cameraControllerProvider.notifier);
    await controller.initialize();
    await controller.setZoomLevel(10);

    expect(container.read(cameraControllerProvider).zoomLevel, 4.0);
    final zoomCall =
        calls.lastWhere((MethodCall call) => call.method == 'setZoomLevel');
    expect((zoomCall.arguments as Map<Object?, Object?>)['zoom'], 4.0);
  });

  test('フラッシュは OFF → AUTO → ON → トーチの順に切り替わる', () async {
    final container = await createContainer();
    final controller = container.read(cameraControllerProvider.notifier);
    await controller.initialize();

    await controller.cycleFlashMode();
    expect(container.read(cameraControllerProvider).flashMode, FlashMode.auto);
    await controller.cycleFlashMode();
    expect(container.read(cameraControllerProvider).flashMode, FlashMode.on);
    await controller.cycleFlashMode();
    expect(container.read(cameraControllerProvider).flashMode, FlashMode.torch);
    await controller.cycleFlashMode();
    expect(container.read(cameraControllerProvider).flashMode, FlashMode.off);
  });
}
