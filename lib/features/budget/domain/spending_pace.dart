/// 支出ペースと月末着地予測のドメインモデル
///
/// 月間予算と当月支出の実績から、1日あたりのペース・月末着地見込みを算出する。
enum SpendingPaceLevel {
  unknown,
  comfortable,
  onTrack,
  caution,
  critical,
  exceeded;

  /// 日本語ラベル
  String get label => switch (this) {
        SpendingPaceLevel.unknown => '判定不能',
        SpendingPaceLevel.comfortable => '余裕',
        SpendingPaceLevel.onTrack => '適正',
        SpendingPaceLevel.caution => '要注意',
        SpendingPaceLevel.critical => '超過確実',
        SpendingPaceLevel.exceeded => '超過中',
      };

  /// 表示用絵文字
  String get emoji => switch (this) {
        SpendingPaceLevel.unknown => '⏳',
        SpendingPaceLevel.comfortable => '🟢',
        SpendingPaceLevel.onTrack => '🔵',
        SpendingPaceLevel.caution => '🟡',
        SpendingPaceLevel.critical => '🟠',
        SpendingPaceLevel.exceeded => '🔴',
      };
}

/// 3桁カンマ区切りの金額文字列に整形する（例: 99200 → '99,200'）
String formatAmount(int amount) {
  final digits = amount.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    buf.write(digits[i]);
    final rest = digits.length - i - 1;
    if (rest > 0 && rest % 3 == 0) buf.write(',');
  }
  return amount < 0 ? '-${buf.toString()}' : buf.toString();
}

/// 支出ペースと月末着地予測の計算結果モデル
class SpendingPace {
  /// 月間予算額（円）。0以下は予算未設定扱い
  final int monthlyBudget;

  /// 当月の総支出額（円）
  final int totalSpent;

  /// 経過日数（今日を含む）= now.day
  final int elapsedDays;

  /// 当月の日数（月跨ぎ・閏年対応）
  final int daysInMonth;

  /// 今日を含む残日数 = daysInMonth - now.day + 1
  final int remainingDays;

  /// 1日あたりの支出ペース = totalSpent / elapsedDays
  final double dailyPace;

  /// 月末着地見込み = (dailyPace * daysInMonth).round()
  final int projectedTotal;

  /// 月末残高見込み = monthlyBudget - projectedTotal（負＝超過見込み）
  final int projectedBalance;

  /// 残日数で割った推奨1日額（予算未設定・残予算なしの場合は0）
  final int recommendedDailyPace;

  /// 現在ペースと推奨ペースの差（正＝超過ペース）
  final int overPacePerDay;

  /// 予算を使い切るまでの日数（超過済=0、予算未設定 or ペース0=null）
  final int? daysUntilBudgetEmpty;

  /// ペース判定レベル
  final SpendingPaceLevel level;

  SpendingPace({
    required this.monthlyBudget,
    required this.totalSpent,
    required this.elapsedDays,
    required this.daysInMonth,
    required this.remainingDays,
    required this.dailyPace,
    required this.projectedTotal,
    required this.projectedBalance,
    required this.recommendedDailyPace,
    required this.overPacePerDay,
    required this.daysUntilBudgetEmpty,
    required this.level,
  }) {
    if (monthlyBudget < 0) {
      throw ArgumentError.value(monthlyBudget, 'monthlyBudget', '負値は不正');
    }
    if (totalSpent < 0) {
      throw ArgumentError.value(totalSpent, 'totalSpent', '負値は不正');
    }
    if (elapsedDays < 0) {
      throw ArgumentError.value(elapsedDays, 'elapsedDays', '負値は不正');
    }
    if (daysInMonth < 0) {
      throw ArgumentError.value(daysInMonth, 'daysInMonth', '負値は不正');
    }
    if (remainingDays < 0) {
      throw ArgumentError.value(remainingDays, 'remainingDays', '負値は不正');
    }
  }

  /// 予算が設定されているか（monthlyBudget > 0）
  bool get isBudgetSet => monthlyBudget > 0;

  /// 着地予測が可能か（予算設定済みかつ経過日数1以上）
  bool get canForecast => monthlyBudget > 0 && elapsedDays >= 1;

  /// 着地見込みが予算超過か
  bool get isOverpaceProjected => projectedTotal > monthlyBudget;

  /// 着地見込みの予算消化率（予算未設定時は0.0）
  double get projectedUsageRatio =>
      monthlyBudget > 0 ? projectedTotal / monthlyBudget : 0.0;

  /// 例: '1日あたり ¥3,200 ペース'
  String get paceLabel =>
      '1日あたり ¥${formatAmount(dailyPace.round())} ペース';

  /// 例: 'このペースだと月末 ¥99,200 着地見込み'
  String get forecastLabel =>
      'このペースだと月末 ¥${formatAmount(projectedTotal)} 着地見込み';

  /// 画面1行要約（レベル絵文字+label+着地見込み）
  String get summaryLabel => '${level.emoji} ${level.label} — $forecastLabel';
}
