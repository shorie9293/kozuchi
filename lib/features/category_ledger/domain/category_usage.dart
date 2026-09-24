/// カテゴリ別の使用実績
class CategoryUsage {
  /// カテゴリ名
  final String category;

  /// amount>0 の件数
  final int count;

  /// 合計金額
  final int amount;

  /// 台帳に存在するか（false=台帳から消えた孤立カテゴリ）
  final bool inLedger;

  const CategoryUsage({
    required this.category,
    required this.count,
    required this.amount,
    required this.inLedger,
  });

  @override
  bool operator ==(Object other) =>
      other is CategoryUsage &&
      other.runtimeType == runtimeType &&
      category == other.category &&
      count == other.count &&
      amount == other.amount &&
      inLedger == other.inLedger;

  @override
  int get hashCode => Object.hash(category, count, amount, inLedger);

  @override
  String toString() =>
      'CategoryUsage($category, count: $count, amount: $amount, '
      'inLedger: $inLedger)';
}
