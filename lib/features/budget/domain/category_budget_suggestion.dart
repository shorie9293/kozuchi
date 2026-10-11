/// カテゴリ別予算の推奨額サジェスト結果を表す不変モデル。
class CategoryBudgetSuggestion {
  CategoryBudgetSuggestion({
    required this.category,
    required this.recommendedBudget,
    required this.averageMonthlySpent,
    required this.maxMonthlySpent,
    required this.monthsWithSpend,
    required this.monthsConsidered,
    required this.yearMonth,
  }) {
    if (category.trim().isEmpty) {
      throw ArgumentError.value(category, 'category', 'must not be blank');
    }
  }

  /// カテゴリ名（trim済み・空なら '未分類' 扱いの実値）
  final String category;

  /// 1000円単位切り上げの推奨額
  final int recommendedBudget;

  /// 実績のある月での平均（round）
  final int averageMonthlySpent;

  /// 窓内の月別最大支出
  final int maxMonthlySpent;

  /// 窓内で支出実績があった月数
  final int monthsWithSpend;

  /// 窓の月数
  final int monthsConsidered;

  /// 推奨の対象月 'YYYY-MM'（=nowの月）
  final String yearMonth;

  /// 窓内で支出実績があった月の割合（0〜1）
  double get coverage =>
      monthsConsidered > 0 ? monthsWithSpend / monthsConsidered : 0;

  /// 推奨額の表示ラベル
  String get recommendedLabel => '¥$recommendedBudget';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryBudgetSuggestion &&
          other.category == category &&
          other.recommendedBudget == recommendedBudget &&
          other.yearMonth == yearMonth;

  @override
  int get hashCode => Object.hash(category, recommendedBudget, yearMonth);
}
