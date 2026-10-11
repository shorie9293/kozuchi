import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/features/budget/domain/category_budget_suggestion.dart';
import 'package:kozuchi/features/budget/domain/category_budget_suggestion_service.dart';

ExpenseEntry _e(String category, int amount, int y, int m, [int d = 10]) =>
    ExpenseEntry(
      id: '$category-$y-$m-$d-$amount',
      amount: amount,
      category: category,
      date: DateTime(y, m, d),
    );

void main() {
  const service = CategoryBudgetSuggestionService();

  group('windowMonths', () {
    test('古い順・ゼロ埋めの月キーを返す', () {
      expect(
        service.windowMonths(DateTime(2026, 1, 15), 3),
        ['2025-11', '2025-12', '2026-01'],
      );
    });

    test('年跨ぎ（4ヶ月窓）', () {
      expect(
        service.windowMonths(DateTime(2026, 1, 15), 4),
        ['2025-10', '2025-11', '2025-12', '2026-01'],
      );
    });

    test('months<=0 は ArgumentError', () {
      expect(() => service.windowMonths(DateTime(2026, 1, 15), 0),
          throwsArgumentError);
      expect(() => service.windowMonths(DateTime(2026, 1, 15), -1),
          throwsArgumentError);
    });
  });

  group('roundUpToNearest', () {
    test('切り上げの境界', () {
      expect(service.roundUpToNearest(999, 1000), 1000);
      expect(service.roundUpToNearest(1000, 1000), 1000);
      expect(service.roundUpToNearest(1001, 1000), 2000);
      expect(service.roundUpToNearest(0, 1000), 0);
      expect(service.roundUpToNearest(-5, 1000), 0);
    });

    test('unit<=0 は ArgumentError', () {
      expect(() => service.roundUpToNearest(100, 0), throwsArgumentError);
    });
  });

  group('suggest', () {
    test('窓外の古い支出は無視される', () {
      final suggestions = service.suggest(
        entries: [
          _e('食費', 30000, 2025, 9),
          _e('食費', 10000, 2025, 12),
        ],
        now: DateTime(2026, 1, 15),
      );
      expect(suggestions, hasLength(1));
      expect(suggestions.single.averageMonthlySpent, 10000);
      expect(suggestions.single.recommendedBudget, 10000);
    });

    test('amount<=0 は無視・空カテゴリは未分類', () {
      final suggestions = service.suggest(
        entries: [
          _e('  ', 5000, 2026, 1),
          _e('交通 ', 1200, 2026, 1),
        ],
        now: DateTime(2026, 1, 15),
      );
      // amount<=0 のエントリは ExpenseEntry の assert で生成不能なため、
      // ここでは空白カテゴリ→'未分類'とtrimの挙動を検証する。
      final byCategory = {for (final s in suggestions) s.category: s};
      expect(byCategory.keys, hasLength(2));
      expect(byCategory['未分類'], isNotNull);
      expect(byCategory['未分類']!.maxMonthlySpent, 5000);
      expect(byCategory['交通'], isNotNull);
      expect(byCategory['食費'], isNull);
    });

    test('平均は実績のある月で割る（3ヶ月窓で2ヶ月分計3万円）', () {
      final suggestions = service.suggest(
        entries: [
          _e('食費', 20000, 2025, 11),
          _e('食費', 10000, 2026, 1),
        ],
        now: DateTime(2026, 1, 15),
      );
      final s = suggestions.single;
      expect(s.averageMonthlySpent, 15000);
      expect(s.recommendedBudget, 15000);
      expect(s.monthsWithSpend, 2);
      expect(s.monthsConsidered, 3);
      expect(s.maxMonthlySpent, 20000);
      expect(s.coverage, closeTo(2 / 3, 1e-9));
      expect(s.yearMonth, '2026-01');
    });

    test('切り上げ: 1ヶ月だけ12,300円なら推奨13,000', () {
      final suggestions = service.suggest(
        entries: [_e('娯楽', 12300, 2025, 12)],
        now: DateTime(2026, 1, 15),
      );
      final s = suggestions.single;
      expect(s.averageMonthlySpent, 12300);
      expect(s.recommendedBudget, 13000);
    });

    test('並び順: recommendedBudget 降順・同額はカテゴリ昇順', () {
      final suggestions = service.suggest(
        entries: [
          _e('交通', 8000, 2025, 12),
          _e('食費', 15000, 2025, 12),
          _e('娯楽', 8000, 2026, 1),
        ],
        now: DateTime(2026, 1, 15),
      );
      expect(
        suggestions.map((s) => s.category).toList(),
        ['食費', '交通', '娯楽'], // Unicode順: 交(4EA4)<娯(5A2F)<食(98DF)…降順は食費が先
      );
    });

    test('実績なしカテゴリは出ない', () {
      // ExpenseEntry の assert(amount>0) により実効額0/負のエントリは生成不能。
      // 窓内に正の支出が一切無いカテゴリは結果に出ないことを検証する。
      final suggestions = service.suggest(
        entries: [_e('食費', 5000, 2025, 8)], // 窓外のみ
        now: DateTime(2026, 1, 15),
      );
      expect(suggestions, isEmpty);
    });

    test('monthsToConsider<=0 は ArgumentError', () {
      expect(
        () => service.suggest(
          entries: const [],
          now: DateTime(2026, 1, 15),
          monthsToConsider: 0,
        ),
        throwsArgumentError,
      );
    });

    test('空 entries は空リスト', () {
      expect(
        service.suggest(entries: const [], now: DateTime(2026, 1, 15)),
        isEmpty,
      );
    });

    test('モデル: category 空文字で ArgumentError・等価性', () {
      expect(
        () => CategoryBudgetSuggestion(
          category: '  ',
          recommendedBudget: 1000,
          averageMonthlySpent: 1000,
          maxMonthlySpent: 1000,
          monthsWithSpend: 1,
          monthsConsidered: 3,
          yearMonth: '2026-01',
        ),
        throwsArgumentError,
      );
      final a = CategoryBudgetSuggestion(
        category: '食費',
        recommendedBudget: 1000,
        averageMonthlySpent: 900,
        maxMonthlySpent: 900,
        monthsWithSpend: 1,
        monthsConsidered: 3,
        yearMonth: '2026-01',
      );
      final b = CategoryBudgetSuggestion(
        category: '食費',
        recommendedBudget: 1000,
        averageMonthlySpent: 999,
        maxMonthlySpent: 500,
        monthsWithSpend: 2,
        monthsConsidered: 3,
        yearMonth: '2026-01',
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a.recommendedLabel, '¥1000');
    });
  });
}
