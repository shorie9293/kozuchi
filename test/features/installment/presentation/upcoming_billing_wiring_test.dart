import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kozuchi/features/installment/presentation/installment_app_keys.dart';
import 'package:kozuchi/screens/main_screen.dart';

/// MainScreen から支払い予定画面への配線を検証する。
///
/// 注意: MainScreen は WashiBackground（AnimationController..repeat()）を含むため
/// pumpAndSettle はタイムアウトする。pump(Duration) で進めること。
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

  testWidgets('支払い予定のクイックリンクから支払い予定画面へ遷移する', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MaterialApp(home: MainScreen()));
    // 初期化（予算・支出・デイリークエスト読込）を進める
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    expect(find.text('📅 支払い予定'), findsOneWidget);

    // クイックリンクはグリッドの下位にあり初期状態では画面外のため、スクロールで見えるまで進める
    await tester.dragUntilVisible(
      find.text('📅 支払い予定'),
      find.byType(Scrollable).first,
      const Offset(0, -200),
    );
    for (var i = 0; i < 2; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    await tester.tap(find.text('📅 支払い予定'));
    // 遷移アニメーションと支払い予定画面の初期ロードを進める
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    expect(find.byKey(InstallmentAppKeys.upcomingScreen), findsOneWidget);
    expect(find.text('支払い予定'), findsOneWidget);
  });
}
