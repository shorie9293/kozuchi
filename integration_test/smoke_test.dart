// 天浮橋計画 — kozuchi スモークテスト
// 単独実行: flutter test integration_test/smoke_test.dart -d <device>
//
// CI では本番の Supabase 資格情報を渡さないため、起動配線の検証に必要な
// 最小限のダミー初期化のみ行う（実サーバーへは通信しない）。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kozuchi/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    try {
      await Supabase.initialize(
        url: 'https://test.supabase.co',
        anonKey: 'test-key',
      );
    } catch (_) {}
  });

  testWidgets('スモーク: アプリ起動と基本画面表示', (tester) async {
    await tester.pumpWidget(const MyApp(isFirstLaunch: true));
    await tester.pump(const Duration(seconds: 2));
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.byType(MaterialApp), findsOneWidget,
        reason: 'kozuchiアプリが正常に起動していること');
  });
}
