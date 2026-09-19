import 'spending_pace.dart';

/// 支出ペース・月末着地予測を計算するサービス
///
/// 純粋ロジックのみ。now は引数注入（DateTime.now() を内部で呼ばない）。
class SpendingPaceService {
  /// 着地見込み <= 予算 * 0.8 → 余裕
  static const double comfortableThreshold = 0.8;

  /// 着地見込み > 予算 * 1.2 → 超過確実
  static const double criticalThreshold = 1.2;

  const SpendingPaceService();

  /// 月間予算と当月支出から支出ペースを計算する
  SpendingPace compute({
    required int totalSpent,
    required int monthlyBudget,
    required DateTime now,
  }) {
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final elapsedDays = now.day;
    final remainingDays = daysInMonth - now.day + 1;
    final dailyPace = totalSpent / elapsedDays;
    final projectedTotal = (dailyPace * daysInMonth).round();
    final projectedBalance = monthlyBudget - projectedTotal;

    final remainingBudget = monthlyBudget - totalSpent;
    final recommendedDailyPace = monthlyBudget <= 0
        ? 0
        : remainingBudget <= 0
            ? 0
            : remainingBudget ~/ remainingDays;
    final overPacePerDay = monthlyBudget <= 0
        ? 0
        : (dailyPace - recommendedDailyPace).round();

    final int? daysUntilBudgetEmpty;
    if (monthlyBudget <= 0) {
      daysUntilBudgetEmpty = null;
    } else if (remainingBudget <= 0) {
      daysUntilBudgetEmpty = 0;
    } else if (dailyPace <= 0) {
      daysUntilBudgetEmpty = null;
    } else {
      daysUntilBudgetEmpty = (remainingBudget / dailyPace).floor();
    }

    return SpendingPace(
      monthlyBudget: monthlyBudget,
      totalSpent: totalSpent,
      elapsedDays: elapsedDays,
      daysInMonth: daysInMonth,
      remainingDays: remainingDays,
      dailyPace: dailyPace,
      projectedTotal: projectedTotal,
      projectedBalance: projectedBalance,
      recommendedDailyPace: recommendedDailyPace,
      overPacePerDay: overPacePerDay,
      daysUntilBudgetEmpty: daysUntilBudgetEmpty,
      level: _judge(
        monthlyBudget: monthlyBudget,
        totalSpent: totalSpent,
        projectedTotal: projectedTotal,
      ),
    );
  }

  /// level 判定（判定順は仕様どおり厳守）
  SpendingPaceLevel _judge({
    required int monthlyBudget,
    required int totalSpent,
    required int projectedTotal,
  }) {
    if (monthlyBudget <= 0) return SpendingPaceLevel.unknown;
    if (totalSpent > monthlyBudget) return SpendingPaceLevel.exceeded;
    if (projectedTotal > monthlyBudget * criticalThreshold) {
      return SpendingPaceLevel.critical;
    }
    if (projectedTotal > monthlyBudget) return SpendingPaceLevel.caution;
    if (projectedTotal > monthlyBudget * comfortableThreshold) {
      return SpendingPaceLevel.onTrack;
    }
    return SpendingPaceLevel.comfortable;
  }
}
