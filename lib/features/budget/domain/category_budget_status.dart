/// カテゴリ別予算の警告状態
///
/// - [ok]: 予算内（閾値未満）
/// - [warning]: 警告域（閾値以上・上限未満）
/// - [exceeded]: 超過（上限以上）
enum CategoryBudgetState { ok, warning, exceeded }

/// カテゴリ別予算の判定結果
///
/// 一つのカテゴリについて、予算上限・当月支出・警告状態を保持する不変モデル。
class CategoryBudgetStatus {
  /// カテゴリ名
  final String category;

  /// 予算上限額（円）
  final int budget;

  /// 当月支出額（円）
  final int spent;

  /// 警告状態
  final CategoryBudgetState state;

  const CategoryBudgetStatus({
    required this.category,
    required this.budget,
    required this.spent,
    required this.state,
  });

  /// 支出の予算に対する比率（0.0〜、上限超過で1.0以上）
  double get ratio => budget > 0 ? spent / budget : 0;

  /// 残り使用可能額（円）
  int get remaining => budget - spent;

  @override
  String toString() =>
      'CategoryBudgetStatus(category: $category, budget: $budget, '
      'spent: $spent, state: $state)';
}
