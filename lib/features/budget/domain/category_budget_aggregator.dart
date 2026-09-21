import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/features/budget/domain/category_budget_service.dart';
import 'package:kozuchi/features/budget/domain/category_budget_status.dart';

/// 支出エントリ群をカテゴリ別予算の判定に橋渡しする純粋ロジック。I/Oを持たない。
class CategoryBudgetAggregator {
  const CategoryBudgetAggregator();

  /// 支出エントリ群から「カテゴリ名 → 支出額合計」を返す。
  /// - amount <= 0 のエントリは無視する
  /// - category が空文字または空白のみの場合は '未分類' として集計する
  /// - 該当なしなら空マップを返す（例外を投げない）
  /// - 集計順序は問わない（Mapのため）
  Map<String, int> spentByCategory(Iterable<ExpenseEntry> entries) {
    final result = <String, int>{};
    for (final entry in entries) {
      if (entry.amount <= 0) continue;
      final category =
          entry.category.trim().isEmpty ? '未分類' : entry.category.trim();
      result[category] = (result[category] ?? 0) + entry.amount;
    }
    return result;
  }

  /// 予算マップと支出マップを CategoryBudgetService に通して判定結果を返す便宜メソッド。
  /// categoryBudgets に budget<=0 のカテゴリが含まれる場合、既存Serviceが除外する
  /// 挙動のままでよい（Serviceに委譲せよ）。
  List<CategoryBudgetStatus> evaluate({
    required Map<String, int> categoryBudgets,
    required Map<String, int> categorySpent,
    CategoryBudgetService service = const CategoryBudgetService(),
  }) {
    return service.evaluate(
      categoryBudgets: categoryBudgets,
      categorySpent: categorySpent,
    );
  }

  /// 支出エントリ群から直接判定する便宜メソッド。
  /// 内部で spentByCategory してから evaluate に委譲する。
  List<CategoryBudgetStatus> evaluateEntries({
    required Map<String, int> categoryBudgets,
    required Iterable<ExpenseEntry> entries,
    CategoryBudgetService service = const CategoryBudgetService(),
  }) {
    return evaluate(
      categoryBudgets: categoryBudgets,
      categorySpent: spentByCategory(entries),
      service: service,
    );
  }
}