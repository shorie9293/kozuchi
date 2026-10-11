import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/features/budget/domain/category_budget_suggestion.dart';

/// 支出実績からカテゴリ別の推奨予算額を算出する純粋サービス。I/Oを持たない。
class CategoryBudgetSuggestionService {
  const CategoryBudgetSuggestionService();

  static const int defaultMonthsToConsider = 3;
  static const int roundingUnit = 1000;

  /// 窓となる月キー('YYYY-MM')を古い順〜nowの月で返す。months<=0 なら ArgumentError。
  List<String> windowMonths(DateTime now, int months) {
    if (months <= 0) {
      throw ArgumentError.value(months, 'months', 'must be positive');
    }
    final result = <String>[];
    var year = now.year;
    var month = now.month;
    for (var i = 0; i < months; i++) {
      result.add('$year-${month.toString().padLeft(2, '0')}');
      month--;
      if (month == 0) {
        month = 12;
        year--;
      }
    }
    return result.reversed.toList(growable: false);
  }

  /// value を unit 単位で切り上げ。value<=0 なら0。unit<=0 なら ArgumentError。
  int roundUpToNearest(int value, int unit) {
    if (unit <= 0) {
      throw ArgumentError.value(unit, 'unit', 'must be positive');
    }
    if (value <= 0) return 0;
    return ((value + unit - 1) ~/ unit) * unit;
  }

  /// 支出実績からカテゴリ別の推奨予算額を算出する。
  List<CategoryBudgetSuggestion> suggest({
    required Iterable<ExpenseEntry> entries,
    required DateTime now,
    int monthsToConsider = defaultMonthsToConsider,
  }) {
    if (monthsToConsider <= 0) {
      throw ArgumentError.value(
        monthsToConsider,
        'monthsToConsider',
        'must be positive',
      );
    }

    final window = windowMonths(now, monthsToConsider);
    final windowSet = window.toSet();
    final monthlyTotals = <String, Map<String, int>>{};
    for (final entry in entries) {
      if (entry.amount <= 0) continue;
      final monthKey =
          '${entry.date.year}-${entry.date.month.toString().padLeft(2, '0')}';
      if (!windowSet.contains(monthKey)) continue;
      final category =
          entry.category.trim().isEmpty ? '未分類' : entry.category.trim();
      final totals = monthlyTotals.putIfAbsent(category, () => <String, int>{});
      totals[monthKey] = (totals[monthKey] ?? 0) + entry.amount;
    }

    final nowKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final suggestions = <CategoryBudgetSuggestion>[];
    for (final finalEntry in monthlyTotals.entries) {
      final category = finalEntry.key;
      final totals = finalEntry.value;
      var total = 0;
      var maxMonthly = 0;
      var monthsWithSpend = 0;
      for (final monthKey in window) {
        final amount = totals[monthKey] ?? 0;
        total += amount;
        if (amount > maxMonthly) maxMonthly = amount;
        if (amount > 0) monthsWithSpend++;
      }
      if (monthsWithSpend == 0) continue;
      final average = (total / monthsWithSpend).round();
      final recommended = roundUpToNearest(average, roundingUnit);
      suggestions.add(CategoryBudgetSuggestion(
        category: category,
        recommendedBudget: recommended,
        averageMonthlySpent: average,
        maxMonthlySpent: maxMonthly,
        monthsWithSpend: monthsWithSpend,
        monthsConsidered: monthsToConsider,
        yearMonth: nowKey,
      ));
    }

    suggestions.sort((a, b) {
      final byBudget = b.recommendedBudget.compareTo(a.recommendedBudget);
      if (byBudget != 0) return byBudget;
      return a.category.compareTo(b.category);
    });
    return suggestions;
  }
}
