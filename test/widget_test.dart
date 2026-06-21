import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:kozuchi/main.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('アプリ起動時にHPバーとEXPゲージが表示される', (tester) async {
    // SharedPreferencesのモックを事前設定（_loadSavedStateで必要）
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MyApp());
    // _loadSavedState() の非同期完了を待つ
    await tester.pump();
    await tester.pump();

    // メイン画面のKey確認
    expect(find.byKey(AppKeys.mainScreen), findsOneWidget);

    // HPバー
    expect(find.text('💰 残高（HP）'), findsOneWidget);

    // EXPゲージ
    expect(find.text('🧘 EXP（悟りゲージ）'), findsOneWidget);

    // 開眼段階
    expect(find.text('レベル1'), findsOneWidget);

    // アドバイザー契約ボタンが表示される
    expect(find.text('アドバイザーと契約する'), findsOneWidget);
  });

  testWidgets('アドバイザー契約ボタンをタップすると選択画面に遷移する', (tester) async {
    // SharedPreferencesのモックを事前設定（_loadSavedStateで必要）
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MyApp());
    // _loadSavedState() の非同期完了を待つ
    await tester.pump();
    await tester.pump();

    // 契約ボタンをタップ
    await tester.tap(find.text('アドバイザーと契約する'));
    await tester.pumpAndSettle();

    // アドバイザー選択画面が表示される
    expect(find.byKey(const Key('advisorSelectionScreen')), findsOneWidget);
  });
}
