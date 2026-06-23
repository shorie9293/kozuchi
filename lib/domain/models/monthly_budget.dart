/// 月間予算モデル
///
/// 月ごとの予算額を保持する不変（immutable）モデル。
/// SharedPreferences で永続化するための JSON シリアライズに対応。
class MonthlyBudget {
  /// 年月（YYYY-MM形式、例: "2026-06"）
  final String yearMonth;

  /// 予算額（円、0は未設定を意味する）
  final int amount;

  const MonthlyBudget({
    required this.yearMonth,
    this.amount = 0,
  }) : assert(amount >= 0, '予算額は0以上である必要があります');

  /// 予算が未設定かどうか
  bool get isNotSet => amount == 0;

  /// JSONから復元
  factory MonthlyBudget.fromJson(Map<String, dynamic> json) {
    return MonthlyBudget(
      yearMonth: json['yearMonth'] as String? ?? '',
      amount: json['amount'] as int? ?? 0,
    );
  }

  /// JSONに変換
  Map<String, dynamic> toJson() {
    return {
      'yearMonth': yearMonth,
      'amount': amount,
    };
  }

  /// 現在の年月を YYYY-MM 形式で返す
  static String currentYearMonth() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    return '${now.year}-$month';
  }

  /// 予算額のみを更新したコピーを返す
  MonthlyBudget copyWith({int? amount}) {
    return MonthlyBudget(
      yearMonth: yearMonth,
      amount: amount ?? this.amount,
    );
  }
}
