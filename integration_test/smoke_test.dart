// 天浮橋計画 — kozuchi スモークテスト
// イシコリドメ（Ishikori）鍛造 — 令和八年皐月二十六日
//
// 単独実行: flutter test integration_test/smoke_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kozuchi/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('スモーク: アプリ起動と基本画面表示', (tester) async {
    await tester.runAsync(() async {
      // kozuchi は isFirstLaunch を SharedPreferences から読む
      runApp(const MyApp(isFirstLaunch: true));
    });

    await tester.pump(const Duration(seconds: 2));
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
    }

    // 基本アプリが起動していることを確認
    expect(find.byType(MaterialApp), findsOneWidget,
        reason: 'kozuchiアプリが正常に起動していること');
  });
}
