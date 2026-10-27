import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/features/about/domain/about_info.dart';
import 'package:kozuchi/features/about/presentation/about_app_keys.dart';
import 'package:kozuchi/features/about/presentation/about_screen.dart';
import 'package:kozuchi/screens/main_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/domain/models/player_model.dart';

/// 試練用に情報を注入した AboutInfo。
final testInfo = AboutInfo(
  appName: 'テストアプリ',
  version: '9.9.9',
  contactEmail: 'test@example.com',
  privacyPolicyUrl: 'https://example.com/privacy',
  tagline: '試練用',
);

/// 試練では外部アプリを撃たない。ランチャーは常に失敗（false）を返し、
/// 従来のコピー導線（ダイアログ）へ退避させる。
Future<void> pumpScreen(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(
    home: AboutScreen(info: testInfo, urlOpener: (_) async => false),
  ));
  await tester.pump();
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: 'https://test.supabase.co',
        anonKey: 'test-key',
      );
    } catch (_) {}
  });

  group('AboutScreen - 表示', () {
    testWidgets('注入した info のアプリ名とバージョンを表示する', (tester) async {
      await pumpScreen(tester);
      expect(find.text('テストアプリ'), findsOneWidget);
      expect(find.byKey(AboutAppKeys.versionText), findsOneWidget);
      expect(find.text('v9.9.9'), findsOneWidget);
    });
  });

  group('AboutScreen - OSSライセンス', () {
    testWidgets('ライセンスタイルをタップすると LicensePage が開く', (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.byKey(AboutAppKeys.licenseTile));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(LicensePage), findsOneWidget);
    });
  });

  group('AboutScreen - プライバシーポリシー', () {
    testWidgets('タップでダイアログにURLが表示される', (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.byKey(AboutAppKeys.privacyTile));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('https://example.com/privacy'), findsOneWidget);
    });

    testWidgets('コピーで SnackBar が出る', (tester) async {
      // 試練環境ではClipboardのプラットフォームチャネルが無いので mock する。
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (message) async {
        return null;
      });
      await pumpScreen(tester);
      await tester.tap(find.byKey(AboutAppKeys.privacyTile));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(AboutAppKeys.dialogCopyButton));
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('AboutScreen - 問い合わせ', () {
    testWidgets('タップでダイアログにメールアドレスが表示される', (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.byKey(AboutAppKeys.contactTile));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('test@example.com'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('コピーで SnackBar が出る', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (message) async {
        return null;
      });
      await pumpScreen(tester);
      await tester.tap(find.byKey(AboutAppKeys.contactTile));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(AboutAppKeys.dialogCopyButton));
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('AboutScreen - 導線（main_screen）', () {
    testWidgets('MainScreen の「アプリについて」から遷移できる', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MainScreen(initialPlayer: PlayerModel(hp: 50000)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      final aboutEntry = find.text('ℹ️ アプリについて');
      // 画面下部に置かれているため、外側ListViewをドラッグして見える化する。
      final listFinder = find.byType(ListView).first;
      for (var i = 0; i < 12; i++) {
        if (aboutEntry.evaluate().isEmpty) {
          await tester.drag(listFinder, const Offset(0, -200));
          await tester.pump(const Duration(milliseconds: 100));
          continue;
        }
        final rect = tester.getRect(aboutEntry);
        if (rect.center.dy < 550) break;
        await tester.drag(listFinder, const Offset(0, -200));
        await tester.pump(const Duration(milliseconds: 100));
      }
      final entryRect = tester.getRect(aboutEntry);
      expect(entryRect.center.dy, lessThan(600), reason: 'タイルが画面内に見えていること');

      await tester.tap(aboutEntry);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AboutScreen), findsOneWidget);
      expect(find.text('コヅチ'), findsOneWidget);
    });
  });
}
