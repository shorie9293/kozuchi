import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/monthly_report/domain/monthly_report_period.dart';
import 'package:kozuchi/features/monthly_report/domain/monthly_report_service.dart';

TransactionModel _tx({
  required int amount,
  String category = '食費',
  String? datetime,
  String purpose = '',
}) {
  return TransactionModel(
    amount: amount,
    purpose: purpose,
    category: category,
    datetime: datetime ?? DateTime(2026, 9, 15, 12).toIso8601String(),
  );
}

final _sept = MonthlyReportPeriod(year: 2026, month: 9);

void main() {
  group('MonthlyReportService.build', () {
    test('取引が空ならゼロの空レポート', () {
      final report =
          MonthlyReportService.build(period: _sept, transactions: const []);
      expect(report.isEmpty, isTrue);
      expect(report.totalIncome, 0);
      expect(report.totalExpense, 0);
      expect(report.balance, 0);
      expect(report.transactionCount, 0);
      expect(report.categories, isEmpty);
      expect(report.savingsRate, 0.0);
    });

    test('収入のみを集計する', () {
      final report = MonthlyReportService.build(period: _sept, transactions: [
        _tx(amount: 300000, category: '給与'),
        _tx(amount: 20000, category: '副収入'),
      ]);
      expect(report.totalIncome, 320000);
      expect(report.totalExpense, 0);
      expect(report.balance, 320000);
      expect(report.transactionCount, 2);
      expect(report.categories, isEmpty);
    });

    test('支出のみを絶対値で集計する', () {
      final report = MonthlyReportService.build(period: _sept, transactions: [
        _tx(amount: -1200, category: '食費'),
        _tx(amount: -800, category: '交通費'),
      ]);
      expect(report.totalExpense, 2000);
      expect(report.totalIncome, 0);
      expect(report.balance, -2000);
      expect(report.transactionCount, 2);
    });

    test('対象月外の取引は無視する', () {
      final report = MonthlyReportService.build(period: _sept, transactions: [
        _tx(amount: -1000, datetime: DateTime(2026, 8, 31, 23).toIso8601String()),
        _tx(amount: -2000, datetime: DateTime(2026, 9, 1).toIso8601String()),
        _tx(amount: -3000, datetime: DateTime(2026, 9, 30, 23).toIso8601String()),
        _tx(amount: -4000, datetime: DateTime(2026, 10, 1).toIso8601String()),
      ]);
      expect(report.totalExpense, 5000);
      expect(report.transactionCount, 2);
    });

    test('datetime が空文字の取引は無視する', () {
      final report = MonthlyReportService.build(period: _sept, transactions: [
        _tx(amount: -1000, datetime: ''),
        _tx(amount: -500),
      ]);
      expect(report.totalExpense, 500);
      expect(report.transactionCount, 1);
    });

    test('datetime がパース不能な取引は無視する', () {
      final report = MonthlyReportService.build(period: _sept, transactions: [
        _tx(amount: -1000, datetime: 'not-a-date'),
        _tx(amount: -500),
      ]);
      expect(report.totalExpense, 500);
      expect(report.transactionCount, 1);
    });

    test('amount 0 は収入にも支出にも数えない', () {
      final report = MonthlyReportService.build(period: _sept, transactions: [
        _tx(amount: 0),
        _tx(amount: -1000),
      ]);
      expect(report.totalIncome, 0);
      expect(report.totalExpense, 1000);
      expect(report.transactionCount, 1);
    });

    test('カテゴリ別に集計し支出降順で並ぶ', () {
      final report = MonthlyReportService.build(period: _sept, transactions: [
        _tx(amount: -1000, category: '食費'),
        _tx(amount: -5000, category: '交通費'),
        _tx(amount: -3000, category: '食費'),
      ]);
      expect(report.categories.length, 2);
      expect(report.categories.first.category, '交通費');
      expect(report.categories.first.amount, 5000);
      expect(report.categories.last.category, '食費');
      expect(report.categories.last.amount, 4000);
    });

    test('カテゴリ金額が同額なら名前昇順', () {
      final report = MonthlyReportService.build(period: _sept, transactions: [
        _tx(amount: -1000, category: 'B'),
        _tx(amount: -1000, category: 'A'),
      ]);
      expect(report.categories.map((c) => c.category).toList(), ['A', 'B']);
    });

    test('空カテゴリは その他 に正規化される', () {
      final report = MonthlyReportService.build(period: _sept, transactions: [
        _tx(amount: -1000, category: ''),
      ]);
      expect(report.categories.single.category, 'その他');
    });

    test('ratio は支出合計に対する割合', () {
      final report = MonthlyReportService.build(period: _sept, transactions: [
        _tx(amount: -7500, category: '食費'),
        _tx(amount: -2500, category: '娯楽'),
      ]);
      expect(report.categories.first.ratio, closeTo(0.75, 1e-9));
      expect(report.categories.last.ratio, closeTo(0.25, 1e-9));
      expect(
        report.categories.fold<double>(0, (s, c) => s + c.ratio),
        closeTo(1.0, 1e-9),
      );
    });

    test('収入も支出もあるとき貯蓄率は balance/income', () {
      final report = MonthlyReportService.build(period: _sept, transactions: [
        _tx(amount: 100000),
        _tx(amount: -25000),
      ]);
      expect(report.savingsRate, closeTo(0.75, 1e-9));
    });

    test('支出が収入を上回る場合は貯蓄率0', () {
      final report = MonthlyReportService.build(period: _sept, transactions: [
        _tx(amount: 10000),
        _tx(amount: -30000),
      ]);
      expect(report.savingsRate, 0.0);
    });

    test('収入ゼロなら貯蓄率0', () {
      final report = MonthlyReportService.build(period: _sept, transactions: [
        _tx(amount: -30000),
      ]);
      expect(report.savingsRate, 0.0);
    });

    test('前月データを渡さないと previousTotalExpense は null', () {
      final report =
          MonthlyReportService.build(period: _sept, transactions: const []);
      expect(report.previousTotalExpense, isNull);
      expect(report.expenseChange, isNull);
      expect(report.expenseChangePercent, isNull);
    });

    test('前月の空リストを渡すと previousTotalExpense は 0', () {
      final report = MonthlyReportService.build(
        period: _sept,
        transactions: [_tx(amount: -1000)],
        previousMonthTransactions: const [],
      );
      expect(report.previousTotalExpense, 0);
      expect(report.expenseChange, 1000);
      expect(report.expenseChangePercent, isNull);
    });

    test('前月データから変化率を算出する（減少）', () {
      final report = MonthlyReportService.build(
        period: _sept,
        transactions: [_tx(amount: -8000)],
        previousMonthTransactions: [
          _tx(amount: -10000,
              datetime: DateTime(2026, 8, 10).toIso8601String()),
        ],
      );
      expect(report.previousTotalExpense, 10000);
      expect(report.expenseChange, -2000);
      expect(report.expenseChangePercent, closeTo(-20.0, 1e-9));
      expect(report.changeLabel, '-20.0%');
    });

    test('前月データから変化率を算出する（増加）', () {
      final report = MonthlyReportService.build(
        period: _sept,
        transactions: [_tx(amount: -15000)],
        previousMonthTransactions: [
          _tx(amount: -10000,
              datetime: DateTime(2026, 8, 10).toIso8601String()),
        ],
      );
      expect(report.expenseChangePercent, closeTo(50.0, 1e-9));
      expect(report.changeLabel, '+50.0%');
    });

    test('前月リスト内の対象月外・不正データは無視する', () {
      final report = MonthlyReportService.build(
        period: _sept,
        transactions: [_tx(amount: -1000)],
        previousMonthTransactions: [
          _tx(amount: -5000,
              datetime: DateTime(2026, 8, 5).toIso8601String()),
          _tx(amount: -9999,
              datetime: DateTime(2026, 7, 5).toIso8601String()),
          _tx(amount: -9999, datetime: 'bad'),
          _tx(amount: 0,
              datetime: DateTime(2026, 8, 6).toIso8601String()),
        ],
      );
      expect(report.previousTotalExpense, 5000);
    });

    test('年跨ぎの前月（1月のレポートは前年12月を見る）', () {
      final jan = MonthlyReportPeriod(year: 2026, month: 1);
      final report = MonthlyReportService.build(
        period: jan,
        transactions: [
          _tx(amount: -1000, datetime: DateTime(2026, 1, 5).toIso8601String()),
        ],
        previousMonthTransactions: [
          _tx(amount: -2000,
              datetime: DateTime(2025, 12, 20).toIso8601String()),
        ],
      );
      expect(report.previousTotalExpense, 2000);
      expect(report.expenseChangePercent, closeTo(-50.0, 1e-9));
    });

    test('元の取引リストを破壊しない', () {
      final transactions = [_tx(amount: -1000), _tx(amount: 500)];
      final snapshot = transactions.map((t) => t.amount).toList();
      MonthlyReportService.build(period: _sept, transactions: transactions);
      expect(transactions.map((t) => t.amount).toList(), snapshot);
    });

    test('未来日付の取引も当月内なら集計する', () {
      final report = MonthlyReportService.build(period: _sept, transactions: [
        _tx(amount: -1000, datetime: DateTime(2026, 9, 30).toIso8601String()),
      ]);
      expect(report.totalExpense, 1000);
    });

    test('カテゴリは支出のみを対象とし収入カテゴリは含めない', () {
      final report = MonthlyReportService.build(period: _sept, transactions: [
        _tx(amount: 50000, category: '給与'),
        _tx(amount: -1000, category: '食費'),
      ]);
      expect(report.categories.length, 1);
      expect(report.categories.single.category, '食費');
      expect(report.categories.single.ratio, closeTo(1.0, 1e-9));
    });

    test('同じカテゴリは合算し件数は取引数で数える', () {
      final report = MonthlyReportService.build(period: _sept, transactions: [
        _tx(amount: -100, category: '食費'),
        _tx(amount: -200, category: '食費'),
        _tx(amount: -300, category: '食費'),
      ]);
      expect(report.categories.single.amount, 600);
      expect(report.transactionCount, 3);
    });
  });
}
