import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mumumu/core/permissions.dart';
import 'package:mumumu/core/settings/settings_controller.dart';
import 'package:mumumu/features/camera/camera_page.dart';
import 'package:mumumu/features/onboarding/onboarding_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _GrantingPermissionService implements PermissionService {
  @override
  Future<bool> hasCapturePermissions() async => true;

  @override
  Future<bool> openSettings() async => true;

  @override
  Future<PermissionOutcome> requestCapturePermissions() async =>
      PermissionOutcome.granted;

  @override
  Future<PermissionOutcome> requestMicrophonePermission() async =>
      PermissionOutcome.granted;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('オンボーディングは注意喚起を表示し、同意で完了を記録する', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
        permissionServiceProvider.overrideWithValue(_GrantingPermissionService()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: const OnboardingPage(),
          routes: <String, WidgetBuilder>{
            CameraPage.routeName: (_) => const Scaffold(body: Text('カメラ')),
          },
        ),
      ),
    );

    expect(find.text('mumumu へようこそ'), findsOneWidget);
    expect(find.text('法令とマナーを守ってください'), findsOneWidget);

    await tester.tap(find.text('同意して始める'));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).onboardingCompleted, isTrue);
    expect(find.text('カメラ'), findsOneWidget);
  });
}
