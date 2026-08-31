import 'category_budget_status.dart';

/// カテゴリ別予算の警告判定サービス
///
/// カテゴリごとの予算上限と当月支出から、警告状態（ok/warning/exceeded）を
/// 判定する純粋ロジック。I/Oを持たず試練（テスト）可能。
class CategoryBudgetService {
  /// 警告閾値（0.0〜1.0、デフォルト0.8＝支出が予算の80%以上で警告）
  final double warningThreshold;

  const CategoryBudgetService({this.warningThreshold = 0.8})
      : assert(warningThreshold > 0 && warningThreshold <= 1.0);

  /// 全カテゴリの予算 vs 支出を判定する
  ///
  /// [categoryBudgets] は カテゴリ名 → 予算上限額（0は未設定で対象外）。
  /// [categorySpent] は カテゴリ名 → 当月支出額。
  /// 結果は 超過→警告→予算内 の順、同状態は金額降順で並べる。
  List<CategoryBudgetStatus> evaluate({
    required Map<String, int> categoryBudgets,
    required Map<String, int> categorySpent,
  }) {
    final result = <CategoryBudgetStatus>[];
    categoryBudgets.forEach((category, budget) {
      if (budget <= 0) return; // 未設定カテゴリは対象外
      final spent = categorySpent[category] ?? 0;
      result.add(CategoryBudgetStatus(
        category: category,
        budget: budget,
        spent: spent,
        state: _state(budget, spent),
      ));
    });

    result.sort((a, b) {
      final stateOrder = a.state.index.compareTo(b.state.index);
      if (stateOrder != 0) return stateOrder;
      return b.budget.compareTo(a.budget);
    });
    return result;
  }

  /// 超過（上限以上）したカテゴリのみを返す
  List<CategoryBudgetStatus> exceeded({
    required Map<String, int> categoryBudgets,
    required Map<String, int> categorySpent,
  }) {
    return evaluate(
      categoryBudgets: categoryBudgets,
      categorySpent: categorySpent,
    ).where((s) => s.state == CategoryBudgetState.exceeded).toList();
  }

  /// 警告域（閾値以上・上限未満）のカテゴリのみを返す
  List<CategoryBudgetStatus> warnings({
    required Map<String, int> categoryBudgets,
    required Map<String, int> categorySpent,
  }) {
    return evaluate(
      categoryBudgets: categoryBudgets,
      categorySpent: categorySpent,
    ).where((s) => s.state == CategoryBudgetState.warning).toList();
  }

  /// 超過したカテゴリが存在するか
  bool hasExceeded({
    required Map<String, int> categoryBudgets,
    required Map<String, int> categorySpent,
  }) {
    return exceeded(
      categoryBudgets: categoryBudgets,
      categorySpent: categorySpent,
    ).isNotEmpty;
  }

  CategoryBudgetState _state(int budget, int spent) {
    if (spent >= budget) return CategoryBudgetState.exceeded;
    final ratio = spent / budget;
    if (ratio >= warningThreshold) return CategoryBudgetState.warning;
    return CategoryBudgetState.ok;
  }
}
