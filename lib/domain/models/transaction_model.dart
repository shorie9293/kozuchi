/// 取引モデル
///
/// 1件の取引（収入または支出）を表す。
/// amount の符号で収入（正）・支出（負）を区別する。
class TransactionModel {
  /// 金額（円）。正 = 収入、負 = 支出。
  final int amount;

  /// 用途
  final String purpose;

  /// カテゴリ
  final String category;

  /// 日時（ISO 8601 形式）
  final String datetime;

  const TransactionModel({
    required this.amount,
    required this.purpose,
    required this.category,
    required this.datetime,
  });

  /// 収入かどうか（amount >= 0）
  bool get isIncome => amount >= 0;

  /// 金額の絶対値
  int get absAmount => amount.abs();

  /// JSON から復元
  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      amount: json['amount'] as int? ?? 0,
      purpose: json['purpose'] as String? ?? '',
      category: json['category'] as String? ?? '',
      datetime: json['datetime'] as String? ?? '',
    );
  }

  /// JSON に変換
  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'purpose': purpose,
      'category': category,
      'datetime': datetime,
    };
  }
}
