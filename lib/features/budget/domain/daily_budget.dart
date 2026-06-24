/// 日割り予算の計算結果モデル
///
/// 月間予算と当月支出から、残日数で割った1日あたりの使用可能額を算出する。
class DailyBudget {
  /// 月間予算額（円）
  final int monthlyBudget;

  /// 当月の総支出額（円）
  final int totalSpent;

  /// 残日数（今日を含む月末までの日数）
  final int remainingDays;

  /// 残予算 = monthlyBudget - totalSpent（0未満の場合は0）
  int get remainingBudget {
    final remaining = monthlyBudget - totalSpent;
    return remaining < 0 ? 0 : remaining;
  }

  /// 予算超過かどうか
  bool get isOverBudget => totalSpent > monthlyBudget;

  /// 予算消化率（0.0〜100.0超）
  double get budgetUsagePercent =>
      monthlyBudget > 0 ? (totalSpent / monthlyBudget) * 100.0 : 0.0;

  /// 1日あたりの使用可能額
  /// 残日数が0の場合は0、残予算が0の場合は0
  int get dailyAllowance {
    if (remainingDays <= 0) return 0;
    if (remainingBudget <= 0) return 0;
    return remainingBudget ~/ remainingDays;
  }

  const DailyBudget({
    required this.monthlyBudget,
    required this.totalSpent,
    required this.remainingDays,
  });

  /// 予算未設定の場合の空インスタンス
  factory DailyBudget.empty() =>
      const DailyBudget(monthlyBudget: 0, totalSpent: 0, remainingDays: 0);

  /// 予算未設定かどうか
  bool get isBudgetNotSet => monthlyBudget == 0;

  @override
  String toString() =>
      'DailyBudget(monthly: ¥$monthlyBudget, spent: ¥$totalSpent, '
      'remaining: ¥$remainingBudget, days: $remainingDays, '
      'daily: ¥$dailyAllowance)';
}
