import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mumumu/app/app.dart';
import 'package:mumumu/app/router.dart';
import 'package:mumumu/core/preferences/settings_controller.dart';
import 'package:mumumu/features/onboarding/onboarding_page.dart';
import 'package:mumumu/features/settings/legal_page.dart';
import 'package:mumumu/features/settings/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> buildApp(Map<String, Object> initialValues) async {
  SharedPreferences.setMockInitialValues(initialValues);
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: <Override>[sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const MumumuApp(),
  );
}

/// 設定画面を開く。
///
/// カメラ画面はネイティブのプレビューを必要とするため、名前付きルートで直接開く。
Future<void> openSettings(WidgetTester tester) async {
  final NavigatorState navigator = tester.state(find.byType(Navigator));
  unawaited(navigator.pushNamed<void>(AppRoutes.settings));
  await tester.pumpAndSettle();
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
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('初回起動ではオンボーディングが表示される', (WidgetTester tester) async {
    await tester.pumpWidget(await buildApp(const <String, Object>{}));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingPage), findsOneWidget);
  });

  testWidgets('設定画面でテーマを切り替えると即座に反映される', (WidgetTester tester) async {
    await tester.pumpWidget(
      await buildApp(const <String, Object>{'onboarding_completed': true}),
    );
    await tester.pump();

    await openSettings(tester);
    expect(find.byType(SettingsPage), findsOneWidget);

    await tapItem(tester, find.byType(DropdownButton<ThemeMode>));
    await tester.tap(find.text('ダーク').last);
    await tester.pumpAndSettle();

    final MaterialApp app = tester.widget(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });

  testWidgets('設定画面から利用規約とプライバシーポリシーを開ける', (WidgetTester tester) async {
    await tester.pumpWidget(
      await buildApp(const <String, Object>{'onboarding_completed': true}),
    );
    await tester.pump();

    await openSettings(tester);

    await tapItem(tester, find.text('利用規約'));
    expect(find.byType(LegalPage), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tapItem(tester, find.text('プライバシーポリシー'));
    expect(find.textContaining('端末外へ一切送信しません'), findsOneWidget);
  });
}
