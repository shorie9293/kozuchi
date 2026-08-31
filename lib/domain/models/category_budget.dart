/// カテゴリ別予算モデル
///
/// カテゴリ（食費/趣味/交通費 等）ごとの月間予算上限を表す不変（immutable）モデル。
/// SharedPreferences で永続化するための JSON シリアライズに対応。
class CategoryBudget {
  /// カテゴリ名（例: 食費, 趣味, 交通費）
  final String category;

  /// 月間予算上限額（円、0は未設定を意味する）
  final int amount;

  const CategoryBudget({
    required this.category,
    this.amount = 0,
  }) : assert(amount >= 0, '予算額は0以上である必要があります');

  /// 予算が未設定かどうか
  bool get isNotSet => amount <= 0;

  /// JSONから復元
  factory CategoryBudget.fromJson(Map<String, dynamic> json) {
    return CategoryBudget(
      category: json['category'] as String? ?? '',
      amount: json['amount'] as int? ?? 0,
    );
  }

  /// JSONに変換
  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'amount': amount,
    };
  }

  /// 予算額のみを更新したコピーを返す
  CategoryBudget copyWith({int? amount}) {
    return CategoryBudget(
      category: category,
      amount: amount ?? this.amount,
    );
  }

  @override
  String toString() => 'CategoryBudget(category: $category, amount: $amount)';
}
