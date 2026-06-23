/// 支出一件を表すモデル
///
/// Kozuchiアプリで記録される支出データの最小単位。
/// 収入は含まず、支出（喜捨・消費）のみを扱う。
class ExpenseEntry {
  /// 一意識別子
  final String id;

  /// 支出金額（円）
  final int amount;

  /// カテゴリ名（例: 食費, 交通費, 娯楽, 住居費, 光熱費, 医療費, 教育費, その他）
  final String category;

  /// 支出日時
  final DateTime date;

  /// 備考（任意）
  final String? note;

  /// レシート画像パス（任意）
  final String? receiptImagePath;

  const ExpenseEntry({
    required this.id,
    required this.amount,
    required this.category,
    required this.date,
    this.note,
    this.receiptImagePath,
  }) : assert(amount > 0, 'amount must be positive');

  /// JSONから復元
  factory ExpenseEntry.fromJson(Map<String, dynamic> json) {
    return ExpenseEntry(
      id: json['id'] as String,
      amount: json['amount'] as int,
      category: json['category'] as String,
      date: DateTime.parse(json['date'] as String),
      note: json['note'] as String?,
      receiptImagePath: json['receiptImagePath'] as String?,
    );
  }

  /// JSONに変換
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'category': category,
      'date': date.toIso8601String(),
      'note': note,
      'receiptImagePath': receiptImagePath,
    };
  }

  @override
  String toString() =>
      'ExpenseEntry(id: $id, amount: $amount, category: $category, date: $date)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpenseEntry &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
