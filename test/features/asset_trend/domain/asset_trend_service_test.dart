import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/asset_trend/domain/asset_trend_service.dart';
import 'package:kozuchi/features/asset_trend/domain/monthly_asset_point.dart';

TransactionModel _tx(int amount, String datetime) => TransactionModel(
      amount: amount,
      purpose: 'test',
      category: amount >= 0 ? '収入' : '支出',
      datetime: datetime,
    );

void main() {
  const service = AssetTrendService();

  group('MonthlyAssetPoint', () {
    test('netChange は 収入 - 支出', () {
      const p = MonthlyAssetPoint(
        year: 2026,
        month: 7,
        income: 200000,
        expense: 50000,
        balance: 150000,
      );
      expect(p.netChange, 150000);
    });

    test('key は 年*12 + (月-1)', () {
      const p = MonthlyAssetPoint(
        year: 2026,
        month: 1,
        income: 0,
        expense: 0,
        balance: 0,
      );
      expect(p.key, 2026 * 12);
    });

    test('label は YYYY/MM 形式（1桁月はゼロ埋め）', () {
      const p = MonthlyAssetPoint(
        year: 2026,
        month: 3,
        income: 0,
        expense: 0,
        balance: 0,
      );
      expect(p.label, '2026/03');
    });
  });

  group('AssetTrendService.buildMonthlyTrend', () {
    test('空の取引リストは空を返す', () {
      expect(service.buildMonthlyTrend([]), isEmpty);
    });

    test('months が 1 未満なら空を返す', () {
      final result = service.buildMonthlyTrend(
        [_tx(1000, '2026-07-01T00:00:00')],
        now: DateTime(2026, 7, 15),
        months: 0,
      );
      expect(result, isEmpty);
    });

    test('収入のみの月は balance = income / expense = 0', () {
      final result = service.buildMonthlyTrend(
        [_tx(100000, '2026-07-01T00:00:00')],
        now: DateTime(2026, 7, 15),
      );
      expect(result, hasLength(1));
      expect(result.single.income, 100000);
      expect(result.single.expense, 0);
      expect(result.single.balance, 100000);
    });

    test('複数月の累積残高が正しく累積される', () {
      final result = service.buildMonthlyTrend(
        [
          _tx(200000, '2026-07-05T10:00:00'),
          _tx(-50000, '2026-07-20T10:00:00'),
          _tx(-30000, '2026-08-10T10:00:00'),
          _tx(-20000, '2026-09-01T10:00:00'),
        ],
        now: DateTime(2026, 9, 15),
      );

      expect(result, hasLength(3));
      expect(result[0].label, '2026/07');
      expect(result[0].balance, 150000);
      expect(result[1].label, '2026/08');
      expect(result[1].balance, 120000);
      expect(result[2].label, '2026/09');
      expect(result[2].balance, 100000);
    });

    test('入力順がバラバラでも昇順に整列される', () {
      final result = service.buildMonthlyTrend(
        [
          _tx(-30000, '2026-08-10T10:00:00'),
          _tx(200000, '2026-07-05T10:00:00'),
        ],
        now: DateTime(2026, 9, 15),
      );
      expect(result.map((p) => p.label).toList(), ['2026/07', '2026/08']);
    });

    test('窓の外の月は除外されるが累積残高は全期間から計算される', () {
      final result = service.buildMonthlyTrend(
        [
          _tx(100000, '2025-01-15T10:00:00'), // 窓の外（14ヶ月前）
          _tx(-40000, '2026-09-10T10:00:00'),
        ],
        now: DateTime(2026, 9, 15),
        months: 12,
      );

      expect(result, hasLength(1));
      expect(result.single.label, '2026/09');
      // 2025年の収入も累積に含まれる
      expect(result.single.balance, 60000);
    });

    test('日付が不正な取引は無視される', () {
      final result = service.buildMonthlyTrend(
        [
          _tx(100000, 'not-a-date'),
          _tx(-10000, '2026-09-01T00:00:00'),
        ],
        now: DateTime(2026, 9, 15),
      );
      expect(result, hasLength(1));
      expect(result.single.income, 0);
      expect(result.single.expense, 10000);
    });

    test('月をまたぐと別バケットに集計される', () {
      final result = service.buildMonthlyTrend(
        [
          _tx(5000, '2026-06-30T23:59:59'),
          _tx(7000, '2026-07-01T00:00:00'),
        ],
        now: DateTime(2026, 7, 15),
      );
      expect(result, hasLength(2));
      expect(result[0].month, 6);
      expect(result[1].month, 7);
    });
  });

  group('AssetTrendService.summarize', () {
    test('空リストは isEmpty=true / averageMonthlyNet=0', () {
      final s = service.summarize([]);
      expect(s.isEmpty, isTrue);
      expect(s.averageMonthlyNet, 0);
      expect(s.bestMonth, isNull);
      expect(s.worstMonth, isNull);
    });

    test('合計・最新残高・平均・最良/最悪月を算出する', () {
      final points = [
        const MonthlyAssetPoint(
          year: 2026,
          month: 7,
          income: 200000,
          expense: 50000,
          balance: 150000,
        ),
        const MonthlyAssetPoint(
          year: 2026,
          month: 8,
          income: 0,
          expense: 30000,
          balance: 120000,
        ),
      ];

      final s = service.summarize(points);
      expect(s.latestBalance, 120000);
      expect(s.totalIncome, 200000);
      expect(s.totalExpense, 80000);
      expect(s.totalNetChange, 120000);
      expect(s.months, 2);
      expect(s.averageMonthlyNet, 60000);
      expect(s.bestMonth?.label, '2026/07');
      expect(s.worstMonth?.label, '2026/08');
      expect(s.isEmpty, isFalse);
    });
  });
}
