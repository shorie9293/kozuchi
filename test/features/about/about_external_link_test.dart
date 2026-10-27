import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/features/about/domain/about_info.dart';
import 'package:kozuchi/features/about/domain/external_url_opener.dart';
import 'package:kozuchi/features/about/presentation/about_app_keys.dart';
import 'package:kozuchi/features/about/presentation/about_screen.dart';

/// 「アプリについて」の外部リンク導線（url_launcher 抽象越し）の試練。
///
/// 実網・実ブラウザ・実メーラーは撃たない。`urlOpener` にフェイクを注入し、
/// 「どの URI が渡されたか」「失敗時に従来のコピー導線へ退避するか」を検証する。
void main() {
  final info = AboutInfo(
    appName: 'テストアプリ',
    version: '9.9.9',
    contactEmail: 'test@example.com',
    privacyPolicyUrl: 'https://example.com/privacy',
    tagline: '試練用タグライン',
  );

  Future<void> pumpWith(
    WidgetTester tester, {
    required ExternalUrlOpener opener,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AboutScreen(info: info, urlOpener: opener),
      ),
    );
    await tester.pump();
  }

  group('ExternalUrlOpener 純粋ヘルパ', () {
    test('externalUri は前後の空白を除去した URI を返す', () {
      expect(
        externalUri('  https://www.yoppala.in/privacy  '),
        Uri.parse('https://www.yoppala.in/privacy'),
      );
    });

    test('externalUri はスキーム無し・空文字・空白のみに null を返す', () {
      expect(externalUri('yoppala.in/privacy'), isNull);
      expect(externalUri(''), isNull);
      expect(externalUri('   '), isNull);
    });

    test('mailtoUri はメールアドレスを mailto: へ変換し空白を除去する', () {
      expect(
        mailtoUri(' horie.shunta@gmail.com '),
        Uri.parse('mailto:horie.shunta@gmail.com'),
      );
    });
  });

  group('プライバシーポリシーの外部遷移', () {
    testWidgets('タップでポリシーURLがランチャーへ渡り、ダイアログは開かない', (tester) async {
      final opened = <Uri>[];
      await pumpWith(tester, opener: (uri) async {
        opened.add(uri);
        return true;
      });

      await tester.tap(find.byKey(AboutAppKeys.privacyTile));
      await tester.pumpAndSettle();

      expect(opened, [Uri.parse('https://example.com/privacy')]);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('ランチャーが false を返したら従来のコピーダイアログへ退避する', (tester) async {
      await pumpWith(tester, opener: (_) async => false);

      await tester.tap(find.byKey(AboutAppKeys.privacyTile));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byKey(AboutAppKeys.dialogUrlText), findsOneWidget);
      expect(find.text('https://example.com/privacy'), findsOneWidget);
      expect(find.byKey(AboutAppKeys.dialogCopyButton), findsOneWidget);
    });

    testWidgets('ランチャーが例外を投げても画面は壊れず退避する', (tester) async {
      await pumpWith(
        tester,
        opener: (_) async => throw StateError('no browser'),
      );

      await tester.tap(find.byKey(AboutAppKeys.privacyTile));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('スキーム無しのURLはランチャーを撃たずにダイアログへ退避する', (tester) async {
      var called = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: AboutScreen(
            info: AboutInfo(
              appName: 'テストアプリ',
              version: '9.9.9',
              contactEmail: 'test@example.com',
              privacyPolicyUrl: 'example.com/privacy',
            ),
            urlOpener: (_) async {
              called++;
              return true;
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(AboutAppKeys.privacyTile));
      await tester.pumpAndSettle();

      expect(called, 0);
      expect(find.byType(AlertDialog), findsOneWidget);
    });
  });

  group('問い合わせの外部遷移', () {
    testWidgets('タップで mailto: URI がランチャーへ渡り、ダイアログは開かない', (tester) async {
      final opened = <Uri>[];
      await pumpWith(tester, opener: (uri) async {
        opened.add(uri);
        return true;
      });

      await tester.tap(find.byKey(AboutAppKeys.contactTile));
      await tester.pumpAndSettle();

      expect(opened, [Uri.parse('mailto:test@example.com')]);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('ランチャーが false を返したらコピーダイアログへ退避する', (tester) async {
      await pumpWith(tester, opener: (_) async => false);

      await tester.tap(find.byKey(AboutAppKeys.contactTile));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('test@example.com'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('ランチャーが例外を投げても退避し、例外は漏れない', (tester) async {
      await pumpWith(
        tester,
        opener: (_) async => throw StateError('no mailer'),
      );

      await tester.tap(find.byKey(AboutAppKeys.contactTile));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
