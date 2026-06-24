/// 月間予算モデル
///
/// 月ごとの予算額を保持する不変（immutable）モデル。
/// SharedPreferences で永続化するための JSON シリアライズに対応。
class MonthlyBudget {
  /// 年月（YYYY-MM形式、例: "2026-06"）
  final String yearMonth;

  /// 予算額（円、0は未設定を意味する）
  final int amount;

  /// 警告閾値（0.0〜1.0、デフォルト0.8＝80%）
  /// nullの場合はデフォルト閾値（0.8）を使用する
  final double? warningThreshold;

  const MonthlyBudget({
    required this.yearMonth,
    this.amount = 0,
    this.warningThreshold,
  }) : assert(amount >= 0, '予算額は0以上である必要があります');

  /// 予算が未設定かどうか
  bool get isNotSet => amount == 0;

  /// 有効な警告閾値（nullならデフォルト0.8）
  double get effectiveThreshold => warningThreshold ?? 0.8;

  /// JSONから復元
  factory MonthlyBudget.fromJson(Map<String, dynamic> json) {
    return MonthlyBudget(
      yearMonth: json['yearMonth'] as String? ?? '',
      amount: json['amount'] as int? ?? 0,
      warningThreshold: json['warningThreshold'] as double?,
    );
  }

  /// JSONに変換
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'yearMonth': yearMonth,
      'amount': amount,
    };
    if (warningThreshold != null) {
      map['warningThreshold'] = warningThreshold;
    }
    return map;
  }

  /// 現在の年月を YYYY-MM 形式で返す
  static String currentYearMonth() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    return '${now.year}-$month';
  }

  /// 予算額のみを更新したコピーを返す
  MonthlyBudget copyWith({int? amount, double? warningThreshold}) {
    return MonthlyBudget(
      yearMonth: yearMonth,
      amount: amount ?? this.amount,
      warningThreshold: warningThreshold ?? this.warningThreshold,
    );
  }
}
