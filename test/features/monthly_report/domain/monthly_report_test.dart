import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/monthly_report/domain/monthly_report.dart';
import 'package:kozuchi/features/monthly_report/domain/monthly_report_period.dart';

MonthlyReport _report({
  int totalIncome = 300000,
  int totalExpense = 100000,
  int transactionCount = 3,
  List<MonthlyReportCategory>? categories,
  int? previousTotalExpense,
  int? expenseChange,
  double? expenseChangePercent,
  double? savingsRate,
}) {
  return MonthlyReport(
    period: MonthlyReportPeriod(year: 2026, month: 9),
    totalIncome: totalIncome,
    totalExpense: totalExpense,
    transactionCount: transactionCount,
    categories: categories ??
        [
          const MonthlyReportCategory(category: '食費', amount: 60000, ratio: 0.6),
          const MonthlyReportCategory(category: '交通費', amount: 40000, ratio: 0.4),
        ],
    previousTotalExpense: previousTotalExpense,
    expenseChange: expenseChange,
    expenseChangePercent: expenseChangePercent,
    savingsRate: savingsRate,
  );
}

void main() {
  group('MonthlyReportCategory', () {
    test('ratio は 0.0..1.0 の範囲が assert される', () {
      expect(
        () => MonthlyReportCategory(category: 'x', amount: 1, ratio: 1.5),
        throwsA(isA<AssertionError>()),
      );
    });

    test('等価性', () {
      const a = MonthlyReportCategory(category: '食費', amount: 100, ratio: 0.5);
      const b = MonthlyReportCategory(category: '食費', amount: 100, ratio: 0.5);
      const c = MonthlyReportCategory(category: '外食', amount: 100, ratio: 0.5);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });

  group('MonthlyReport', () {
    test('balance は 収入 - 支出', () {
      expect(_report(totalIncome: 300000, totalExpense: 120000).balance, 180000);
    });

    test('balance は赤字でも負値', () {
      expect(_report(totalIncome: 50000, totalExpense: 80000).balance, -30000);
    });

    test('isEmpty は取引ゼロで true', () {
      expect(_report(transactionCount: 0).isEmpty, isTrue);
      expect(_report(transactionCount: 1).isEmpty, isFalse);
    });

    test('changeLabel: 前月データなし', () {
      expect(_report().changeLabel, '先月データなし');
    });

    test('changeLabel: 前月データありで変化率 null なら 先月データなし', () {
      expect(
        _report(previousTotalExpense: 0, expenseChange: 1000).changeLabel,
        '先月データなし',
      );
    });

    test('changeLabel: 1%未満は 先月とほぼ同じ', () {
      expect(
        _report(previousTotalExpense: 100000, expenseChangePercent: 0.4)
            .changeLabel,
        '先月とほぼ同じ',
      );
      expect(
        _report(previousTotalExpense: 100000, expenseChangePercent: -0.9)
            .changeLabel,
        '先月とほぼ同じ',
      );
    });

    test('changeLabel: 減少は -12.3% 形式', () {
      expect(
        _report(previousTotalExpense: 100000, expenseChangePercent: -12.34)
            .changeLabel,
        '-12.3%',
      );
    });

    test('changeLabel: 増加は +25.0% 形式', () {
      expect(
        _report(previousTotalExpense: 100000, expenseChangePercent: 25.0)
            .changeLabel,
        '+25.0%',
      );
    });

    test('savingsRateLabel は貯蓄率を小数1桁で表す', () {
      expect(_report(savingsRate: 0.6667).savingsRateLabel, '貯蓄率 66.7%');
      expect(_report(savingsRate: 0.0).savingsRateLabel, '貯蓄率 0.0%');
    });

    test('savingsRate 未指定なら 0.0', () {
      expect(_report().savingsRate, 0.0);
    });

    test('savingsRate は 0.0..1.0 にクランプされる', () {
      expect(_report(savingsRate: -0.5).savingsRate, 0.0);
      expect(_report(savingsRate: 1.8).savingsRate, 1.0);
    });

    test('topCategories(0) は ArgumentError', () {
      expect(() => _report().topCategories(0), throwsArgumentError);
    });

    test('topCategories は先頭から n 件', () {
      final report = _report(categories: const [
        MonthlyReportCategory(category: 'a', amount: 3, ratio: 0.5),
        MonthlyReportCategory(category: 'b', amount: 2, ratio: 0.3),
        MonthlyReportCategory(category: 'c', amount: 1, ratio: 0.2),
      ]);
      final top2 = report.topCategories(2);
      expect(top2.length, 2);
      expect(top2.first.category, 'a');
      expect(top2.last.category, 'b');
    });

    test('topCategories は件数超過なら全件', () {
      expect(_report().topCategories(10).length, 2);
    });

    test('topCategories の戻り値は変更不可', () {
      expect(
        () => _report().topCategories(1).add(
              const MonthlyReportCategory(
                  category: 'x', amount: 1, ratio: 0.1),
            ),
        throwsUnsupportedError,
      );
    });

    test('shareText はヘッダと各値を含む', () {
      final text = _report(
        totalIncome: 300000,
        totalExpense: 100000,
        previousTotalExpense: 80000,
        expenseChange: 20000,
        expenseChangePercent: 25.0,
        savingsRate: 200000 / 300000,
      ).shareText;
      expect(text, contains('2026年9月 家計レポート'));
      expect(text, contains('収入: 300000円'));
      expect(text, contains('支出: 100000円'));
      expect(text, contains('収支: +200000円'));
      expect(text, contains('貯蓄率 66.7%'));
      expect(text, contains('前月比: +25.0%'));
      expect(text, contains('TOPカテゴリ:'));
      expect(text, contains('- 食費: 60000円 (60.0%)'));
    });

    test('shareText は赤字の収支を符号付きで示す', () {
      final text = _report(totalIncome: 10000, totalExpense: 30000).shareText;
      expect(text, contains('収支: -20000円'));
    });

    test('shareText はデータ無し月の文言を返す', () {
      final text = _report(transactionCount: 0).shareText;
      expect(text, contains('2026年9月 家計レポート'));
      expect(text, contains('この月の記録はありません'));
    });

    test('shareText はカテゴリが無い場合 TOPカテゴリ を出さない', () {
      final text = _report(categories: const []).shareText;
      expect(text, isNot(contains('TOPカテゴリ')));
    });

    test('等価性はカテゴリ・期間・金額を見る', () {
      expect(_report(), equals(_report()));
      expect(_report(totalExpense: 1), isNot(equals(_report())));
    });
  });
}
