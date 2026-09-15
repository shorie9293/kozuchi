import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/monthly_report/domain/monthly_report.dart';
import 'package:kozuchi/features/monthly_report/domain/monthly_report_period.dart';
import 'package:kozuchi/features/monthly_report/presentation/widgets/monthly_report_card_view.dart';

MonthlyReport _report({
  int totalIncome = 300000,
  int totalExpense = 100000,
  int transactionCount = 3,
  List<MonthlyReportCategory>? categories,
  int? previousTotalExpense,
  double? expenseChangePercent,
  double savingsRate = 0.5,
}) {
  return MonthlyReport(
    period: MonthlyReportPeriod(year: 2026, month: 9),
    totalIncome: totalIncome,
    totalExpense: totalExpense,
    transactionCount: transactionCount,
    categories: categories ??
        const [
          MonthlyReportCategory(category: '食費', amount: 60000, ratio: 0.6),
          MonthlyReportCategory(category: '交通費', amount: 40000, ratio: 0.4),
        ],
    previousTotalExpense: previousTotalExpense,
    expenseChangePercent: expenseChangePercent,
    savingsRate: savingsRate,
  );
}

Future<void> _pump(WidgetTester tester, MonthlyReport report) async {
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: MonthlyReportCardView(report: report))),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('MonthlyReportCardView', () {
    testWidgets('タイトルに期間ラベルを表示する', (tester) async {
      await _pump(tester, _report());
      expect(find.text('2026年9月 家計レポート'), findsOneWidget);
    });

    testWidgets('収入・支出・収支を円表記で表示する', (tester) async {
      await _pump(tester, _report());
      expect(find.text('収入'), findsOneWidget);
      expect(find.text('300000円'), findsOneWidget);
      expect(find.text('支出'), findsOneWidget);
      expect(find.text('100000円'), findsOneWidget);
      expect(find.text('+200000円'), findsOneWidget);
    });

    testWidgets('赤字の収支はマイナス表記', (tester) async {
      await _pump(
        tester,
        _report(totalIncome: 10000, totalExpense: 30000),
      );
      expect(find.text('-20000円'), findsOneWidget);
    });

    testWidgets('貯蓄率と前月比を表示する', (tester) async {
      await _pump(
        tester,
        _report(previousTotalExpense: 80000, expenseChangePercent: 25.0),
      );
      expect(find.text('貯蓄率 50.0%'), findsOneWidget);
      expect(find.text('前月比 +25.0%'), findsOneWidget);
    });

    testWidgets('前月データが無ければ 前月比 先月データなし', (tester) async {
      await _pump(tester, _report());
      expect(find.text('前月比 先月データなし'), findsOneWidget);
    });

    testWidgets('TOP3カテゴリのみバーを描画する', (tester) async {
      await _pump(
        tester,
        _report(categories: const [
          MonthlyReportCategory(category: '食費', amount: 50, ratio: 0.5),
          MonthlyReportCategory(category: '交通費', amount: 20, ratio: 0.2),
          MonthlyReportCategory(category: '娯楽', amount: 20, ratio: 0.2),
          MonthlyReportCategory(category: '住居費', amount: 5, ratio: 0.05),
          MonthlyReportCategory(category: '医療費', amount: 5, ratio: 0.05),
        ]),
      );
      expect(find.text('TOP3カテゴリ'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNWidgets(3));
      expect(find.text('住居費'), findsNothing);
    });

    testWidgets('カテゴリが無ければ TOP3カテゴリ を出さない', (tester) async {
      await _pump(tester, _report(categories: const []));
      expect(find.text('TOP3カテゴリ'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('データ無し月は記録なしの文言を表示する', (tester) async {
      await _pump(
        tester,
        _report(transactionCount: 0, totalIncome: 0, totalExpense: 0),
      );
      expect(find.text('2026年9月 家計レポート'), findsOneWidget);
      expect(find.text('この月の記録はありません'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('カード幅は固定', (tester) async {
      await _pump(tester, _report());
      final size = tester.getSize(find.byType(MonthlyReportCardView));
      expect(size.width, MonthlyReportCardView.cardWidth);
    });
  });
}
