import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:kozuchi/features/settings/presentation/settings_hub_app_keys.dart';
import 'package:kozuchi/features/settings/presentation/settings_hub_screen.dart';
import 'package:kozuchi/screens/main_screen.dart';

/// 設定ハブ画面の試練。
///
/// 遷移先は WidgetBuilder で注入できるため、実画面の依存（通知サービス等）を
/// 起動せずに配線だけを検証する。MainScreen は WashiBackground の
/// AnimationController..repeat() を含むため pumpAndSettle は使わない。
Widget _stub(String label) => Scaffold(body: Center(child: Text(label)));

Future<void> _pumpHub(
  WidgetTester tester, {
  WidgetBuilder? textScaleBuilder,
  WidgetBuilder? notificationBuilder,
  WidgetBuilder? aboutBuilder,
  VoidCallback? onToggleTheme,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: SettingsHubScreen(
      textScaleBuilder: textScaleBuilder,
      notificationBuilder: notificationBuilder,
      aboutBuilder: aboutBuilder,
      onToggleTheme: onToggleTheme,
    ),
  ));
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: 'https://test.supabase.co',
        anonKey: 'test-key',
      );
    } catch (_) {}
  });

  group('SettingsHubScreen - 表示', () {
    testWidgets('AppBar に「設定」を出し、全設定項目を列挙する', (tester) async {
      await _pumpHub(tester);

      expect(find.text('設定'), findsOneWidget);
      expect(find.text('文字サイズ'), findsOneWidget);
      expect(find.text('動きを減らす'), findsOneWidget);
      expect(find.text('アプリロック'), findsOneWidget);
      expect(find.text('通知設定'), findsOneWidget);
      expect(find.text('静穏時間（おやすみモード）'), findsOneWidget);
      expect(find.text('バックアップ'), findsOneWidget);
      expect(find.text('アプリについて'), findsOneWidget);
      expect(find.text('テーマ切替'), findsOneWidget);
      expect(find.byKey(SettingsHubAppKeys.list), findsOneWidget);
    });

    testWidgets('各項目に Semantics 識別子が付く', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpHub(tester);

      expect(
        find.bySemanticsIdentifier('btn_settings_hub_text_scale'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('btn_settings_hub_notification'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('btn_settings_hub_theme'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('SettingsHubScreen - 遷移', () {
    testWidgets('文字サイズをタップすると注入したビルダーが呼ばれる', (tester) async {
      var calls = 0;
      await _pumpHub(tester, textScaleBuilder: (_) {
        calls++;
        return _stub('文字サイズ画面');
      });

      await tester.tap(find.byKey(SettingsHubAppKeys.textScaleTile));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(calls, 1);
      expect(find.text('文字サイズ画面'), findsOneWidget);
    });

    testWidgets('通知設定をタップすると注入したビルダーが呼ばれる', (tester) async {
      var calls = 0;
      await _pumpHub(tester, notificationBuilder: (_) {
        calls++;
        return _stub('通知設定画面');
      });

      await tester.tap(find.byKey(SettingsHubAppKeys.notificationTile));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(calls, 1);
      expect(find.text('通知設定画面'), findsOneWidget);
    });

    testWidgets('ビルダー未指定なら実画面（AboutScreen）へ遷移する', (tester) async {
      await _pumpHub(tester);

      await tester.tap(find.byKey(SettingsHubAppKeys.aboutTile));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 実画面の AppBar タイトル。
      expect(find.text('アプリについて'), findsWidgets);
    });

    testWidgets('テーマ切替タップで注入したコールバックが呼ばれる', (tester) async {
      var toggled = 0;
      await _pumpHub(tester, onToggleTheme: () => toggled++);

      await tester.tap(find.byKey(SettingsHubAppKeys.themeTile));
      await tester.pump();

      expect(toggled, 1);
    });
  });

  group('SettingsHubScreen - ホームからの導線', () {
    testWidgets('⚙️ 設定 タップで SettingsHubScreen が開く', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(const MaterialApp(home: MainScreen()));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }

      final link = find.text('⚙️ 設定');
      await tester.ensureVisible(link);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      await tester.tap(link);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }

      expect(find.byType(SettingsHubScreen), findsOneWidget);
    });
  });
}
