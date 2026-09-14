import 'goal.dart';

/// 貯蓄目標の達成予測結果（不変モデル）
///
/// 現在の貯蓄ペースから達成見込み日・期限截止符・必要月額を保持する。
class GoalForecast {
  /// 月次貯蓄ペース（createdAt から now までの平均・正の整数・切り上げ）
  final int monthlyPace;

  /// 期限内に届くために必要な月額（期限なし or 現在ペースで届く場合は null）
  final int? requiredMonthly;

  /// 達成見込み日（ペース未確定 or 即達成では null）
  final DateTime? forecastDate;

  /// 期限内に現在ペースで届くか（即達成も true）
  final bool isOnTrack;

  /// 残り必要額（即達成では 0・負にはならない）
  final int remainingAmount;

  /// 期限までの残月数（期限なし・期限切れでは null）
  final int? monthsRemaining;

  /// 特別な状態の通知文（中止・目標金額未設定など・通常は null）
  final String? notice;

  const GoalForecast({
    required this.monthlyPace,
    required this.requiredMonthly,
    required this.forecastDate,
    required this.isOnTrack,
    required this.remainingAmount,
    required this.monthsRemaining,
    this.notice,
  });

  /// 予測の一行サマリ
  ///
  /// [deadlineLabel] には期限日文字列（YYYY-MM-DD）または null を渡す。
  String forecastSummary(String? deadlineLabel) {
    final n = notice;
    if (n != null) return n;
    if (remainingAmount <= 0) {
      return '🎉 達成済み';
    }
    if (monthlyPace <= 0) {
      return '📊 まだペースを計測できません';
    }
    final date = forecastDate;
    if (date != null) {
      return '📈 この調子なら ${date.year}年${date.month}月に達成見込み';
    }
    final required = requiredMonthly;
    if (required != null) {
      final months = monthsRemaining;
      final term = months == null ? '' : '（あと${months}ヶ月）';
      return '⏳ 期限までに月${_formatYen(required)}$term が必要';
    }
    if (deadlineLabel != null) {
      return '⚠️ 期限（$deadlineLabel）を過ぎています';
    }
    return '📊 予測を計算できません';
  }

  static String _formatYen(int amount) {
    final s = amount.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write(',');
      buffer.write(s[i]);
    }
    return '¥$buffer';
  }
}

/// 貯蓄目標の達成予測を算出するサービス（純粋ロジック）
class GoalForecastService {
  /// [goal] の達成予測を算出する
  ///
  /// - [now] は基準日（テスト注入可）
  /// - current >= target または completed は即達成扱い
  /// - cancelled は予測対象外（notice で通知）
  /// - target = 0 は予測不能（notice で通知）
  /// - 現在金額が負（借金状態）は1年での返済想定で予測する
  /// - 期限切れは必要月額を算出せず期限超過を通知する
  static GoalForecast forecast(Goal goal, {required DateTime now}) {
    // 予測対象外（目標金額が未設定）
    if (goal.targetAmount <= 0) {
      return GoalForecast(
        monthlyPace: 0,
        requiredMonthly: null,
        forecastDate: null,
        isOnTrack: false,
        remainingAmount: 0,
        monthsRemaining: null,
        notice: '🎯 目標金額を設定すると予測できます',
      );
    }

    // 予測対象外（中止）
    if (goal.isCancelled) {
      return GoalForecast(
        monthlyPace: 0,
        requiredMonthly: null,
        forecastDate: null,
        isOnTrack: false,
        remainingAmount: goal.targetAmount - goal.currentAmount,
        monthsRemaining: null,
        notice: '⏸️ この目標は中止されています',
      );
    }

    final remaining = goal.targetAmount - goal.currentAmount;

    // 即達成
    if (goal.isCompleted || remaining <= 0) {
      return const GoalForecast(
        monthlyPace: 0,
        requiredMonthly: null,
        forecastDate: null,
        isOnTrack: true,
        remainingAmount: 0,
        monthsRemaining: null,
      );
    }

    final deadline = DateTime.tryParse(goal.deadline ?? '');
    final monthsRemaining = deadline == null
        ? null
        : _monthsBetween(now, deadline);

    // 期限切れ
    if (monthsRemaining != null && monthsRemaining <= 0) {
      return GoalForecast(
        monthlyPace: _paceOf(goal, now),
        requiredMonthly: null,
        forecastDate: null,
        isOnTrack: false,
        remainingAmount: remaining,
        monthsRemaining: 0,
        notice: '⚠️ 期限（${goal.deadline}）を過ぎています',
      );
    }

    final elapsedMonths = _calendarMonthsBetween(goal.createdAt, now);

    // 作成直後（ペース未確定）
    if (elapsedMonths <= 0) {
      return GoalForecast(
        monthlyPace: 0,
        requiredMonthly: null,
        forecastDate: null,
        isOnTrack: false,
        remainingAmount: remaining,
        monthsRemaining: monthsRemaining,
      );
    }

    // 月次ペース（切り上げ）。負残高は1年での返済想定
    final int pace;
    if (goal.currentAmount < 0) {
      pace = (remaining / 12).ceil();
    } else {
      final p = (goal.currentAmount / elapsedMonths).ceil();
      pace = p <= 0 ? 0 : p;
    }

    // ペース未確定（貯蓄実績ゼロ）
    if (pace <= 0) {
      return GoalForecast(
        monthlyPace: 0,
        requiredMonthly: null,
        forecastDate: null,
        isOnTrack: false,
        remainingAmount: remaining,
        monthsRemaining: monthsRemaining,
      );
    }

    // 達成見込み日 = now + ceil(remaining / pace) ヶ月
    final monthsToGoal = (remaining / pace).ceil();
    final forecastDate = _addMonths(now, monthsToGoal);

    // 期限判定
    final int? requiredMonthly;
    final bool isOnTrack;
    if (monthsRemaining != null) {
      if (monthsToGoal <= monthsRemaining) {
        requiredMonthly = null;
        isOnTrack = true;
      } else {
        requiredMonthly = (remaining / monthsRemaining).ceil();
        isOnTrack = false;
      }
    } else {
      requiredMonthly = null;
      isOnTrack = true;
    }

    return GoalForecast(
      monthlyPace: pace,
      requiredMonthly: requiredMonthly,
      forecastDate: forecastDate,
      isOnTrack: isOnTrack,
      remainingAmount: remaining,
      monthsRemaining: monthsRemaining,
    );
  }

  static int _paceOf(Goal goal, DateTime now) {
    final elapsedMonths = _calendarMonthsBetween(goal.createdAt, now);
    if (elapsedMonths <= 0) return 0;
    final p = (goal.currentAmount / elapsedMonths).ceil();
    return p <= 0 ? 0 : p;
  }

  /// 暦月ベースの月数（同月内は 0・to.day < from.day は未満とみなす）
  static int _calendarMonthsBetween(DateTime from, DateTime to) {
    if (!to.isAfter(from)) return 0;
    var months =
        (to.year - from.year) * 12 + (to.month - from.month);
    if (to.day < from.day) months -= 1;
    return months < 0 ? 0 : months;
  }

  /// 月を31日近似した月数（切り上げ）
  static int _monthsBetween(DateTime from, DateTime to) {
    if (!to.isAfter(from)) return 0;
    final days = to.difference(from).inDays;
    return (days / 31).ceil();
  }

  static DateTime _addMonths(DateTime base, int months) {
    final total = base.month - 1 + months;
    final year = base.year + total ~/ 12;
    final month = total % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = base.day > lastDay ? lastDay : base.day;
    return DateTime(year, month, day);
  }
}
