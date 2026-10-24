import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/income/domain/models/income_entry.dart';
import 'package:kozuchi/features/monthly_report/domain/income_transaction_merger.dart';
import 'package:kozuchi/features/monthly_report/domain/monthly_report_period.dart';
import 'package:kozuchi/features/monthly_report/domain/monthly_report_service.dart';

IncomeEntry _income({
  required int amount,
  String source = '給与',
  required DateTime date,
  String? note,
  String? id,
}) {
  return IncomeEntry(
    id: id ?? 'inc-$source-$amount',
    amount: amount,
    source: source,
    date: date,
    note: note,
  );
}

TransactionModel _expense({
  required int amount,
  String category = '食費',
  required DateTime date,
}) {
  return TransactionModel(
    amount: amount,
    purpose: category,
    category: category,
    datetime: date.toIso8601String(),
  );
}

final _sept = MonthlyReportPeriod(year: 2026, month: 9);

void main() {
  group('IncomeTransactionMerger.toTransaction', () {
    test('amount は正で元の収入額と一致する', () {
      final tx = IncomeTransactionMerger.toTransaction(
        _income(amount: 300000, date: DateTime(2026, 9, 25, 10)),
      );
      expect(tx.amount, 300000);
      expect(tx.amount, greaterThan(0));
      expect(tx.isIncome, isTrue);
    });

    test('category は source になる', () {
      final tx = IncomeTransactionMerger.toTransaction(
        _income(amount: 50000, source: '副業', date: DateTime(2026, 9, 3)),
      );
      expect(tx.category, '副業');
    });

    test('purpose は note を優先する', () {
      final tx = IncomeTransactionMerger.toTransaction(
        _income(
          amount: 50000,
          source: '副業',
          date: DateTime(2026, 9, 3),
          note: 'デザイン案件',
        ),
      );
      expect(tx.purpose, 'デザイン案件');
    });

    test('note が null なら purpose は source にフォールバックする', () {
      final tx = IncomeTransactionMerger.toTransaction(
        _income(amount: 50000, source: '副業', date: DateTime(2026, 9, 3)),
      );
      expect(tx.purpose, '副業');
    });

    test('datetime は ISO8601 で往復可能', () {
      final date = DateTime(2026, 9, 25, 10, 30, 15);
      final tx = IncomeTransactionMerger.toTransaction(
        _income(amount: 1000, date: date),
      );
      expect(tx.datetime, date.toIso8601String());
      expect(DateTime.parse(tx.datetime), date);
    });

    test('id とレシート画像は付与しない（支出由来情報を持たない）', () {
      final tx = IncomeTransactionMerger.toTransaction(
        _income(amount: 1000, date: DateTime(2026, 9, 1)),
      );
      expect(tx.id, isNull);
      expect(tx.receiptImagePath, isNull);
    });
  });

  group('IncomeTransactionMerger.within', () {
    test('期間内の収入のみを返す', () {
      final entries = [
        _income(amount: 100, date: DateTime(2026, 8, 31, 23, 59), id: 'aug'),
        _income(amount: 200, date: DateTime(2026, 9, 1), id: 'sep-start'),
        _income(amount: 300, date: DateTime(2026, 9, 15), id: 'sep-mid'),
        _income(amount: 400, date: DateTime(2026, 10, 1), id: 'oct'),
      ];
      final result = IncomeTransactionMerger.within(entries, _sept);
      expect(result.map((e) => e.id).toList(), ['sep-start', 'sep-mid']);
    });

    test('start ちょうど（1日 0時）は含む', () {
      final entries = [
        _income(amount: 100, date: DateTime(2026, 9, 1), id: 'start'),
      ];
      expect(IncomeTransactionMerger.within(entries, _sept), hasLength(1));
    });

    test('end 当日は時刻に関わらず含む（日単位の境界）', () {
      final entries = [
        _income(
            amount: 100, date: DateTime(2026, 9, 30, 23, 59, 59), id: 'end'),
      ];
      final result = IncomeTransactionMerger.within(entries, _sept);
      expect(result.map((e) => e.id).toList(), ['end']);
    });

    test('end の前日 23:59 と翌月1日 0時は除外する', () {
      final entries = [
        _income(amount: 100, date: DateTime(2026, 9, 29, 23, 59), id: 'in'),
        _income(amount: 200, date: DateTime(2026, 10, 1), id: 'oct'),
      ];
      final result = IncomeTransactionMerger.within(entries, _sept);
      expect(result.map((e) => e.id).toList(), ['in']);
    });

    test('空リストは空を返す', () {
      expect(IncomeTransactionMerger.within(const [], _sept), isEmpty);
    });

    test('元リストを破壊しない', () {
      final entries = [
        _income(amount: 100, date: DateTime(2026, 8, 1), id: 'a'),
        _income(amount: 200, date: DateTime(2026, 9, 1), id: 'b'),
      ];
      IncomeTransactionMerger.within(entries, _sept);
      expect(entries.map((e) => e.id).toList(), ['a', 'b']);
      expect(entries, hasLength(2));
    });
  });

  group('IncomeTransactionMerger.merge', () {
    test('支出の順序を保持し、収入は後段に date 昇順で並ぶ', () {
      final expenses = [
        _expense(amount: -1000, category: '食費', date: DateTime(2026, 9, 20)),
        _expense(amount: -5000, category: '家賃', date: DateTime(2026, 9, 2)),
        _expense(amount: -3000, category: '交通費', date: DateTime(2026, 9, 10)),
      ];
      final incomes = [
        _income(amount: 50000, source: '副業', date: DateTime(2026, 9, 25)),
        _income(amount: 300000, source: '給与', date: DateTime(2026, 9, 5)),
      ];
      final merged = IncomeTransactionMerger.merge(
        expenses: expenses,
        incomes: incomes,
        period: _sept,
      );
      expect(merged.map((t) => t.amount).toList(),
          [-1000, -5000, -3000, 300000, 50000]);
      expect(merged.take(3).map((t) => t.amount).toList(),
          expenses.map((t) => t.amount).toList());
      expect(merged.skip(3).map((t) => t.category).toList(), ['給与', '副業']);
    });

    test('期間外の収入は合流させない', () {
      final merged = IncomeTransactionMerger.merge(
        expenses: [_expense(amount: -1000, date: DateTime(2026, 9, 20))],
        incomes: [
          _income(amount: 999999, date: DateTime(2026, 8, 31), id: 'out'),
          _income(amount: 1000, date: DateTime(2026, 9, 20), id: 'in'),
        ],
        period: _sept,
      );
      expect(merged.map((t) => t.amount).toList(), [-1000, 1000]);
    });

    test('支出だけなら支出のみをその順序で返す', () {
      final expenses = [
        _expense(amount: -1000, date: DateTime(2026, 9, 20)),
        _expense(amount: -2000, date: DateTime(2026, 9, 1)),
      ];
      final merged = IncomeTransactionMerger.merge(
        expenses: expenses,
        incomes: const [],
        period: _sept,
      );
      expect(merged.map((t) => t.amount).toList(), [-1000, -2000]);
    });

    test('収入だけなら収入のみを date 昇順で返す', () {
      final merged = IncomeTransactionMerger.merge(
        expenses: const [],
        incomes: [
          _income(amount: 200, date: DateTime(2026, 9, 20), id: 'b'),
          _income(amount: 100, date: DateTime(2026, 9, 5), id: 'a'),
        ],
        period: _sept,
      );
      expect(merged.map((t) => t.amount).toList(), [100, 200]);
    });

    test('両方空なら空を返す', () {
      final merged = IncomeTransactionMerger.merge(
        expenses: const [],
        incomes: const [],
        period: _sept,
      );
      expect(merged, isEmpty);
    });

    test('同一日時の収入は入力順を保つ', () {
      final merged = IncomeTransactionMerger.merge(
        expenses: const [],
        incomes: [
          _income(
              amount: 100, source: 'A', date: DateTime(2026, 9, 10), id: '1'),
          _income(
              amount: 200, source: 'B', date: DateTime(2026, 9, 10), id: '2'),
        ],
        period: _sept,
      );
      expect(merged.map((t) => t.category).toList(), ['A', 'B']);
    });

    test('元リストを破壊しない', () {
      final expenses = [_expense(amount: -1000, date: DateTime(2026, 9, 20))];
      final incomes = [
        _income(amount: 500, date: DateTime(2026, 9, 25), id: 'b'),
        _income(amount: 400, date: DateTime(2026, 9, 5), id: 'a'),
      ];
      IncomeTransactionMerger.merge(
        expenses: expenses,
        incomes: incomes,
        period: _sept,
      );
      expect(expenses, hasLength(1));
      expect(incomes.map((e) => e.id).toList(), ['b', 'a']);
    });
  });

  group('合流結果を MonthlyReportService に渡す統合', () {
    test('支出200000＋収入300000 で totalIncome/balance/savingsRate が一致する', () {
      final expenses = [
        _expense(amount: -80000, category: '家賃', date: DateTime(2026, 9, 1)),
        _expense(amount: -70000, category: '食費', date: DateTime(2026, 9, 10)),
        _expense(amount: -50000, category: '光熱費', date: DateTime(2026, 9, 20)),
      ];
      final incomes = [
        _income(amount: 300000, source: '給与', date: DateTime(2026, 9, 25)),
      ];

      final merged = IncomeTransactionMerger.merge(
        expenses: expenses,
        incomes: incomes,
        period: _sept,
      );
      final report =
          MonthlyReportService.build(period: _sept, transactions: merged);

      expect(report.totalExpense, 200000);
      expect(report.totalIncome, 300000);
      expect(report.balance, 100000);
      expect(report.savingsRate, closeTo(1 / 3, 1e-9));
      expect(report.transactionCount, 4);
      expect(report.categories.map((c) => c.category).toList(),
          ['家賃', '食費', '光熱費']);
    });

    test('収入が無ければ totalIncome 0 / savingsRate 0.0（回帰）', () {
      final merged = IncomeTransactionMerger.merge(
        expenses: [
          _expense(amount: -120000, date: DateTime(2026, 9, 1)),
          _expense(amount: -80000, date: DateTime(2026, 9, 15)),
        ],
        incomes: const [],
        period: _sept,
      );
      final report =
          MonthlyReportService.build(period: _sept, transactions: merged);

      expect(report.totalIncome, 0);
      expect(report.totalExpense, 200000);
      expect(report.balance, -200000);
      expect(report.savingsRate, 0.0);
    });

    test('期間外の収入は合流後も集計に混ざらない', () {
      final merged = IncomeTransactionMerger.merge(
        expenses: [_expense(amount: -1000, date: DateTime(2026, 9, 5))],
        incomes: [
          _income(amount: 777777, date: DateTime(2026, 10, 2), id: 'out'),
          _income(amount: 2000, date: DateTime(2026, 9, 6), id: 'in'),
        ],
        period: _sept,
      );
      final report =
          MonthlyReportService.build(period: _sept, transactions: merged);

      expect(report.totalIncome, 2000);
      expect(report.totalExpense, 1000);
      expect(report.balance, 1000);
    });
  });
}
