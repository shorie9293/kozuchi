/// カテゴリ別円グラフのデータモデル
///
/// 支出のカテゴリ名・金額・割合を保持する。
/// [CategoryPieChartWidget] に渡すデータ単位。
class CategoryPieData {
  /// カテゴリ名（例: '食費', '交通費', '娯楽'）
  final String categoryName;

  /// 支出金額
  final double amount;

  /// 全体に占める割合（0.0〜100.0）
  final double percentage;

  const CategoryPieData({
    required this.categoryName,
    required this.amount,
    required this.percentage,
  });

  /// パーセンテージの合計が100になるよう正規化したリストを返す
  static List<CategoryPieData> normalize(List<CategoryPieData> items) {
    final totalPercentage = items.fold<double>(0, (sum, item) => sum + item.percentage);
    if (totalPercentage == 0 || totalPercentage == 100) return items;

    return items
        .map((item) => CategoryPieData(
              categoryName: item.categoryName,
              amount: item.amount,
              percentage: (item.percentage / totalPercentage) * 100,
            ))
        .toList();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryPieData &&
          categoryName == other.categoryName &&
          amount == other.amount &&
          percentage == other.percentage;

  @override
  int get hashCode => Object.hash(categoryName, amount, percentage);

  @override
  String toString() =>
      'CategoryPieData(categoryName: $categoryName, amount: $amount, percentage: $percentage)';
}
