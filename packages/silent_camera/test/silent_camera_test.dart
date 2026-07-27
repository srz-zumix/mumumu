import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silent_camera/silent_camera.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dev.srzzumix.mumumu/silent_camera');
  final List<MethodCall> calls = <MethodCall>[];

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
              'minZoom': 0.5,
              'maxZoom': 8.0,
              'zoomPresets': <Object?>[0.5, 1.0, 2.0],
            },
          ];
        case 'silenceCapability':
          return <Object?, Object?>{
            'isSilent': true,
            'deviceModel': 'Test Device',
            'reason': null,
          };
        case 'initialize':
          return <Object?, Object?>{
            'textureId': 7,
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
            'uri': 'content://media/external/images/media/1',
            'filePath': '/tmp/IMG_20260101_010101.jpg',
            'width': 4032,
            'height': 3024,
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

  test('availableCameras はカメラ情報を解析する', () async {
    final cameras = await SilentCamera.instance.availableCameras();
    expect(cameras, hasLength(1));
    expect(cameras.first.lensDirection, CameraLensDirection.back);
    expect(cameras.first.zoomPresets, <double>[0.5, 1, 2]);
  });

  test('silenceCapability は端末情報を解析する', () async {
    final capability = await SilentCamera.instance.silenceCapability();
    expect(capability.isSilent, isTrue);
    expect(capability.deviceModel, 'Test Device');
    expect(capability.reason, isNull);
  });

  test('initialize は引数を渡しセッションを返す', () async {
    final session = await SilentCamera.instance.initialize(
      lensDirection: CameraLensDirection.front,
      aspectRatio: AspectRatioPreset.ratio16x9,
    );
    expect(session.textureId, 7);
    expect(session.previewSize.width, 1440);
    expect(session.captureMode, CaptureMode.silent);
    expect(calls.single.arguments, <String, Object?>{
      'lensDirection': 'front',
      'captureMode': 'silent',
      'aspectRatio': 'ratio16x9',
    });
  });

  test('capture は保存結果を解析する', () async {
    final result = await SilentCamera.instance.capture(jpegQuality: 80);
    expect(result.uri, 'content://media/external/images/media/1');
    expect(result.width, 4032);
    expect(result.capturedAt.millisecondsSinceEpoch, 1767229261000);
    expect(
      calls.single.arguments,
      <String, Object?>{
        'format': 'jpeg',
        'jpegQuality': 80,
        'mirrorFrontCamera': false,
      },
    );
  });

  test('パラメータ変更はネイティブへ委譲される', () async {
    await SilentCamera.instance.setFlashMode(FlashMode.torch);
    await SilentCamera.instance.setZoomLevel(2.5);
    await SilentCamera.instance.setFocusPoint(0.25, 0.75);
    await SilentCamera.instance.setFocusExposureLocked(locked: true);
    await SilentCamera.instance.setExposureOffset(-1);

    expect(
      calls.map((MethodCall call) => call.method).toList(),
      <String>[
        'setFlashMode',
        'setZoomLevel',
        'setFocusPoint',
        'setFocusExposureLocked',
        'setExposureOffset',
      ],
    );
    expect(calls.first.arguments, <String, Object?>{'mode': 'torch'});
  });
}
