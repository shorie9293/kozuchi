import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/main.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  testWidgets('アプリ起動時に目標支出ゲージとEXPゲージが表示される', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MyApp());
    await tester.pump();
    await tester.pump();
    await tester.pump();

    // メイン画面のKey確認
    expect(find.byKey(AppKeys.mainScreen), findsOneWidget);

    // 目標支出ゲージ（予算未設定状態 — 固定ヘッダーに常時表示）
    expect(find.text('今月の目標支出'), findsOneWidget);

    // EXPゲージ（目標タブ内に表示）
    expect(find.text('🧘 EXP（悟りゲージ）'), findsOneWidget);

    // アプリバーのタイトル
    expect(find.text('打ち出の小槌'), findsOneWidget);
  });
}
