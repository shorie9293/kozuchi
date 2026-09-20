import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/transaction_filter/presentation/transaction_query_app_keys.dart';
import 'package:kozuchi/features/transaction_filter/presentation/widgets/transaction_query_summary_bar.dart';

void main() {
  group('TransactionQuerySummaryBar', () {
    Future<void> pumpBar(
      WidgetTester tester, {
      required int count,
      required int totalIncome,
      required int totalExpense,
      required bool isEmpty,
      VoidCallback? onReset,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionQuerySummaryBar(
              count: count,
              totalIncome: totalIncome,
              totalExpense: totalExpense,
              isEmpty: isEmpty,
              onReset: onReset,
            ),
          ),
        ),
      );
    }

    testWidgets('件数・収入合計・支出合計を表示する', (tester) async {
      await pumpBar(
        tester,
        count: 12,
        totalIncome: 3000,
        totalExpense: 8400,
        isEmpty: false,
      );

      expect(find.text('12件 / 収入 ¥3,000 / 支出 ¥8,400'), findsOneWidget);
    });

    testWidgets('3桁区切りの金額を整形する', (tester) async {
      expect(TransactionQuerySummaryBar.formatYen(1234567), '¥1,234,567');
      expect(TransactionQuerySummaryBar.formatYen(0), '¥0');
      expect(TransactionQuerySummaryBar.formatYen(-500), '¥-500');
    });

    testWidgets('0件時は空状態文言を表示する', (tester) async {
      await pumpBar(
        tester,
        count: 0,
        totalIncome: 0,
        totalExpense: 0,
        isEmpty: true,
      );

      expect(find.text('該当する取引がありません'), findsOneWidget);
    });

    testWidgets('onResetがあればリセットボタンを表示し、タップで発火する', (tester) async {
      var resetCalled = 0;
      await pumpBar(
        tester,
        count: 1,
        totalIncome: 0,
        totalExpense: 0,
        isEmpty: false,
        onReset: () => resetCalled++,
      );

      expect(find.byKey(TransactionQueryAppKeys.resetButton), findsOneWidget);

      await tester.tap(find.byKey(TransactionQueryAppKeys.resetButton));
      await tester.pump();

      expect(resetCalled, 1);
    });

    testWidgets('onResetがnullならリセットボタンを表示しない', (tester) async {
      await pumpBar(
        tester,
        count: 1,
        totalIncome: 0,
        totalExpense: 0,
        isEmpty: false,
      );

      expect(find.byKey(TransactionQueryAppKeys.resetButton), findsNothing);
    });
  });
}