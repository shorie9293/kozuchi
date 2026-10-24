import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/domain/services/expense_repository_impl.dart';
import 'package:kozuchi/features/income/domain/models/income_entry.dart';
import 'package:kozuchi/features/income/domain/services/income_repository.dart';
import 'package:kozuchi/features/monthly_report/domain/income_transaction_merger.dart';
import 'package:kozuchi/features/monthly_report/domain/monthly_report.dart';
import 'package:kozuchi/features/monthly_report/domain/monthly_report_period.dart';
import 'package:kozuchi/features/monthly_report/domain/monthly_report_service.dart';
import 'package:kozuchi/features/monthly_report/presentation/screens/monthly_report_screen.dart';
import 'package:kozuchi/features/monthly_report/presentation/widgets/monthly_report_card_view.dart';

/// 月次レポートへの収入合流（禍津: 収入が常に0として表示される嘘）の試練。
///
/// 検証観点:
/// 1. 収入が実数としてカードへ反映され、画面側が独自集計していないこと
/// 2. 収入0件なら従来どおり（貯蓄率0%）であることの回帰
/// 3. 期間外（前月・翌月）の収入が当月へ混入しないこと
/// 4. カードの描画値が MonthlyReportService.build の出力と完全一致すること
void main() {
  final period = MonthlyReportPeriod(year: 2026, month: 9);

  ExpenseEntry expense({
    required String id,
    required int amount,
    required DateTime date,
    String category = '食費',
  }) {
    return ExpenseEntry(
      id: id,
      amount: amount,
      category: category,
      date: date,
    );
  }

  IncomeEntry income({
    required String id,
    required int amount,
    required DateTime date,
    String source = '給与',
  }) {
    return IncomeEntry(id: id, amount: amount, source: source, date: date);
  }

  /// 画面が使うのと同じ経路（merger -> service）で期待レポートを組む。
  MonthlyReport expectedReport({
    required List<ExpenseEntry> current,
    required List<ExpenseEntry> previous,
    required List<IncomeEntry> incomes,
  }) {
    List<TransactionModel> toTx(List<ExpenseEntry> entries) => entries
        .map((e) => TransactionModel(
              amount: -e.amount.abs(),
              purpose: e.note ?? '',
              category: e.category,
              datetime: e.date.toIso8601String(),
            ))
        .toList();

    return MonthlyReportService.build(
      period: period,
      transactions: IncomeTransactionMerger.merge(
        expenses: toTx(current),
        incomes: incomes,
        period: period,
      ),
      previousMonthTransactions: IncomeTransactionMerger.merge(
        expenses: toTx(previous),
        incomes: incomes,
        period: period.previous,
      ),
    );
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    required List<ExpenseEntry> expenses,
    required IncomeRepository incomeRepository,
  }) async {
    // カード全体が縦に収まるよう縦長ビューポートにする
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = InMemoryExpenseRepository();
    for (final e in expenses) {
      await repository.saveEntry(e);
    }

    await tester.pumpWidget(
      MaterialApp(
        home: MonthlyReportScreen(
          repository: repository,
          incomeRepository: incomeRepository,
          initialMonth: DateTime(2026, 9, 1),
          now: DateTime(2026, 9, 15),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  MonthlyReportCardView cardOf(WidgetTester tester) =>
      tester.widget<MonthlyReportCardView>(find.byType(MonthlyReportCardView));

  group('MonthlyReportScreen 収入合流', () {
    testWidgets('収入300000/支出200000でカードに収入が反映される（貯蓄率33.3%）', (tester) async {
      final incomes = [income(id: 'i1', amount: 300000, date: DateTime(2026, 9, 10))];
      final expenses = [
        expense(id: 'e1', amount: 200000, date: DateTime(2026, 9, 5)),
      ];
      final repo = InMemoryIncomeRepository();
      for (final i in incomes) {
        await repo.saveEntry(i);
      }

      await pumpScreen(tester, expenses: expenses, incomeRepository: repo);

      final expected = expectedReport(
        current: expenses,
        previous: const [],
        incomes: incomes,
      );
      // サービス出力そのもの（画面が独自集計していないことの担保）
      expect(expected.totalIncome, 300000);
      expect(expected.totalExpense, 200000);
      expect(expected.savingsRate, closeTo(1 / 3, 1e-9));

      final card = cardOf(tester);
      expect(card.report, expected);
      expect(find.text('300000円'), findsOneWidget);
      expect(find.text('200000円'), findsOneWidget);
      expect(find.text('+100000円'), findsOneWidget);
      expect(find.text('貯蓄率 33.3%'), findsOneWidget);
    });

    testWidgets('収入0件なら従来どおり貯蓄率0.0%（回帰）', (tester) async {
      final expenses = [
        expense(id: 'e1', amount: 200000, date: DateTime(2026, 9, 5)),
      ];

      await pumpScreen(
        tester,
        expenses: expenses,
        incomeRepository: InMemoryIncomeRepository(),
      );

      final card = cardOf(tester);
      expect(card.report.totalIncome, 0);
      expect(card.report.savingsRate, 0.0);
      expect(find.text('0円'), findsOneWidget); // 収入行
      expect(find.text('貯蓄率 0.0%'), findsOneWidget);
      expect(find.text('-200000円'), findsOneWidget); // 収支
    });

    testWidgets('前月・翌月の収入は当月レポートに混入しない', (tester) async {
      final incomes = [
        income(id: 'i0', amount: 500000, date: DateTime(2026, 8, 25)),
        income(id: 'i1', amount: 300000, date: DateTime(2026, 9, 10)),
        income(id: 'i2', amount: 700000, date: DateTime(2026, 10, 3)),
      ];
      final expenses = [
        expense(id: 'e1', amount: 200000, date: DateTime(2026, 9, 5)),
      ];
      final repo = InMemoryIncomeRepository();
      for (final i in incomes) {
        await repo.saveEntry(i);
      }

      await pumpScreen(tester, expenses: expenses, incomeRepository: repo);

      final expected = expectedReport(
        current: expenses,
        previous: const [],
        incomes: incomes,
      );
      expect(expected.totalIncome, 300000);

      final card = cardOf(tester);
      expect(card.report, expected);
      expect(card.report.totalIncome, 300000);
      expect(find.text('300000円'), findsOneWidget);
      expect(find.text('500000円'), findsNothing);
      expect(find.text('700000円'), findsNothing);
      expect(find.text('貯蓄率 33.3%'), findsOneWidget);
    });

    testWidgets('カードの描画値が MonthlyReportService.build の出力と完全一致する', (tester) async {
      final incomes = [
        income(id: 'i1', amount: 300000, date: DateTime(2026, 9, 10)),
        income(
          id: 'i2',
          amount: 45000,
          date: DateTime(2026, 9, 25),
          source: '副業',
        ),
      ];
      final expenses = [
        expense(id: 'e1', amount: 120000, date: DateTime(2026, 9, 5)),
        expense(
          id: 'e2',
          amount: 30000,
          date: DateTime(2026, 8, 20),
          category: '交通費',
        ),
      ];
      final currentExpenses =
          expenses.where((e) => period.contains(e.date)).toList();
      final previousExpenses =
          expenses.where((e) => period.previous.contains(e.date)).toList();

      final repo = InMemoryIncomeRepository();
      for (final i in incomes) {
        await repo.saveEntry(i);
      }

      await pumpScreen(tester, expenses: expenses, incomeRepository: repo);

      final expected = expectedReport(
        current: currentExpenses,
        previous: previousExpenses,
        incomes: incomes,
      );

      // ウィジェットの描画値（レポートオブジェクト）がサービス出力と完全一致
      final card = cardOf(tester);
      expect(card.report, expected);
      expect(card.report.totalIncome, expected.totalIncome);
      expect(card.report.totalExpense, expected.totalExpense);
      expect(card.report.balance, expected.balance);
      expect(card.report.savingsRate, expected.savingsRate);
      expect(card.report.savingsRateLabel, expected.savingsRateLabel);

      // 描画された文字列もサービス出力から導出した値と一致する
      expect(find.text('${expected.totalIncome}円'), findsOneWidget);
      final balanceLabel =
          '${expected.balance >= 0 ? '+' : '-'}${expected.balance.abs()}円';
      expect(find.text(balanceLabel), findsOneWidget);
      expect(find.text(expected.savingsRateLabel), findsOneWidget);
      expect(find.text('前月比 ${expected.changeLabel}'), findsOneWidget);
    });
  });
}
