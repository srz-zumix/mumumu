import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mumumu/core/preferences/settings_controller.dart';
import 'package:mumumu/features/settings/legal_page.dart';
import 'package:mumumu/features/settings/settings_page.dart';
import 'package:mumumu/platform/silent_camera_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silent_camera/silent_camera.dart';

Future<Widget> buildSettingsPage(Map<String, Object> initialValues) async {
  SharedPreferences.setMockInitialValues(initialValues);
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: <Override>[
      sharedPreferencesProvider.overrideWithValue(prefs),
      silenceCapabilityProvider.overrideWith(
        (Ref ref) async => const SilenceCapability(
          isSilentCaptureSupported: true,
          isShutterSoundEnforcedByOs: false,
          deviceModel: 'test-device',
        ),
      ),
    ],
    child: const MaterialApp(home: SettingsPage()),
  );
}

/// 一覧をスクロールして項目を表示し、タップする。
Future<void> tapItem(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('位置情報の付与は既定で無効である', (WidgetTester tester) async {
    await tester.pumpWidget(await buildSettingsPage(const <String, Object>{}));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('位置情報を付与する'), 200);
    final SwitchListTile tile = tester.widget(
      find.ancestor(
        of: find.text('位置情報を付与する'),
        matching: find.byType(SwitchListTile),
      ),
    );

    expect(tile.value, isFalse);
  });

  testWidgets('テーマを変更すると設定に保存される', (WidgetTester tester) async {
    await tester.pumpWidget(await buildSettingsPage(const <String, Object>{}));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byType(DropdownButton<ThemeMode>),
      200,
    );
    await tester.ensureVisible(find.byType(DropdownButton<ThemeMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<ThemeMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ダーク').last);
    await tester.pumpAndSettle();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_mode'), 'dark');
  });

  testWidgets('利用規約とプライバシーポリシーを開ける', (WidgetTester tester) async {
    await tester.pumpWidget(await buildSettingsPage(const <String, Object>{}));
    await tester.pumpAndSettle();

    await tapItem(tester, find.text('利用規約'));

    expect(find.byType(LegalPage), findsOneWidget);
    expect(find.textContaining('盗撮'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tapItem(tester, find.text('プライバシーポリシー'));

    expect(find.textContaining('端末外へ一切送信しません'), findsOneWidget);
  });

  testWidgets('端末の無音撮影対応状況を表示する', (WidgetTester tester) async {
    await tester.pumpWidget(await buildSettingsPage(const <String, Object>{}));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('test-device'), 200);
    expect(find.textContaining('静音撮影に対応しています。'), findsOneWidget);
  });
}
