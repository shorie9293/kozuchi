import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/player_model.dart';
import 'package:kozuchi/features/income/presentation/screens/income_input_screen.dart';

void main() {
  group('IncomeInputScreen', () {
    testWidgets('収入を記録すると残高(HP)が加算されて結果が返る',
        (WidgetTester tester) async {
      const initialHp = 50000;
      final player = PlayerModel(hp: initialHp, exp: 100);

      IncomeResult? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final r = await Navigator.of(context).push<IncomeResult>(
                  MaterialPageRoute(
                    builder: (_) => IncomeInputScreen(player: player),
                  ),
                );
                result = r;
              },
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // 金額を入力
      await tester.enterText(
        find.widgetWithText(TextFormField, '収入金額（円）'),
        '30000',
      );
      // 収入源を入力
      await tester.enterText(
        find.widgetWithText(TextFormField, '収入源'),
        '給与',
      );

      // 記録ボタンを押下
      await tester.tap(find.widgetWithText(ElevatedButton, '収入を記録する'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.amount, 30000);
      expect(result!.source, '給与');
      // 残高が加算されていること（addHp のロジックがアプリ全体で機能）
      expect(result!.updatedPlayer.hp, initialHp + 30000);
      // 元のEXPが保持されていること
      expect(result!.updatedPlayer.exp, 100);
    });

    testWidgets('金額未入力ではバリデーションエラーで記録されない',
        (WidgetTester tester) async {
      final player = PlayerModel(hp: 50000);
      IncomeResult? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final r = await Navigator.of(context).push<IncomeResult>(
                  MaterialPageRoute(
                    builder: (_) => IncomeInputScreen(player: player),
                  ),
                );
                result = r;
              },
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // 金額を空のまま記録ボタンを押下
      await tester.tap(find.widgetWithText(ElevatedButton, '収入を記録する'));
      await tester.pumpAndSettle();

      // 結果は返らない（バリデーションで弾かれる）
      expect(result, isNull);
      // エラーメッセージが表示される
      expect(find.text('金額を入力せよ'), findsOneWidget);
    });
  });
}
