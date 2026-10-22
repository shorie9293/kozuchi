import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/features/weekly_quest/domain/models/active_weekly_quest.dart';
import 'package:kozuchi/features/weekly_quest/domain/models/weekly_quest.dart';
import 'package:kozuchi/features/weekly_quest/domain/weekly_quest_period.dart';

/// 週次クエストの進捗スナップショット。
///
/// 集計結果と判定済みステータスを保持するだけの値オブジェクト。
/// 表示文字列の組み立てもここに閉じ込め、UI 側は並べるだけでよい。
class WeeklyQuestProgress {
  /// 対象クエスト。
  final WeeklyQuest quest;

  /// 週内の対象カテゴリ支出合計（円）。
  final int spentAmount;

  /// 残り日数（0..7）。
  final int remainingDays;

  /// 週が終了しているか。
  final bool hasEnded;

  /// 判定済みステータス。
  final WeeklyQuestStatus status;

  const WeeklyQuestProgress({
    required this.quest,
    required this.spentAmount,
    required this.remainingDays,
    required this.hasEnded,
    required this.status,
  });

  /// 消化率（0.0..1.0）。budgetLimit が 0 以下なら 1.0。
  double get ratio {
    final limit = quest.budgetLimit;
    if (limit <= 0) return 1.0;
    return (spentAmount / limit).clamp(0.0, 1.0).toDouble();
  }

  /// 残り使える金額（0 未満にはしない）。
  int get remainingAmount {
    final rest = quest.budgetLimit - spentAmount;
    return rest < 0 ? 0 : rest;
  }

  /// 予算内か（ちょうどは予算内）。
  bool get isWithinBudget => spentAmount <= quest.budgetLimit;

  /// 支出表示 例: `'¥8,000 / ¥10,000'`。
  String get spentLabel =>
      '${formatYen(spentAmount)} / ${formatYen(quest.budgetLimit)}';

  /// ステータス表示ラベル。
  String get statusLabel {
    switch (status) {
      case WeeklyQuestStatus.pending:
        return '選択待ち';
      case WeeklyQuestStatus.active:
        return '挑戦中';
      case WeeklyQuestStatus.completed:
        return '達成！';
      case WeeklyQuestStatus.failed:
        return '超過';
    }
  }

  /// 要約表示。
  ///
  /// - 予算超過: `'¥X 超過'`
  /// - 予算内で週継続中: `'残り¥X・あとN日'`
  /// - 予算内で週終了: `'達成！¥X の余裕'`
  String get summaryLabel {
    if (!isWithinBudget) {
      return '${formatYen(spentAmount - quest.budgetLimit)} 超過';
    }
    if (!hasEnded) {
      return '残り${formatYen(remainingAmount)}・あと$remainingDays日';
    }
    return '達成！${formatYen(remainingAmount)} の余裕';
  }

  /// 3桁カンマ区切りの円表記（intl 非依存）。
  static String formatYen(int amount) {
    final negative = amount < 0;
    final digits = amount.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return '${negative ? '-' : ''}¥$buffer';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeeklyQuestProgress &&
          quest == other.quest &&
          spentAmount == other.spentAmount &&
          remainingDays == other.remainingDays &&
          hasEnded == other.hasEnded &&
          status == other.status;

  @override
  int get hashCode =>
      quest.hashCode ^
      spentAmount.hashCode ^
      remainingDays.hashCode ^
      hasEnded.hashCode ^
      status.hashCode;

  @override
  String toString() => 'WeeklyQuestProgress(quest: ${quest.id}, '
      'spent: $spentAmount/${quest.budgetLimit}, status: ${status.name})';
}

/// 週次クエストの支出集計と状態判定。
///
/// `DateTime.now()` は決して呼ばない。現在時刻は必ず引数で注入する。
class WeeklyQuestProgressService {
  const WeeklyQuestProgressService();

  /// 「総支出」を意味するカテゴリ名。
  static const String totalCategory = '総支出';

  /// 対象カテゴリの週内支出合計を求める。
  ///
  /// 対象は `period.contains(entry.date)` かつ `entry.amount > 0` のみ。
  /// `quest.targetCategory == '総支出'` ならカテゴリを問わず合算、
  /// それ以外は完全一致（正規化しない）。
  int spentFor({
    required WeeklyQuest quest,
    required List<ExpenseEntry> entries,
    required WeeklyQuestPeriod period,
  }) {
    var total = 0;
    for (final entry in entries) {
      if (entry.amount <= 0) continue;
      if (!period.contains(entry.date)) continue;
      if (quest.targetCategory != totalCategory &&
          entry.category != quest.targetCategory) {
        continue;
      }
      total += entry.amount;
    }
    return total;
  }

  /// 1件のクエストの進捗を評価する。
  ///
  /// 判定順序（凍結）:
  /// 1. `baseStatus == pending` → pending
  /// 2. `spentAmount > budgetLimit` → failed（週の途中でも即 failed）
  /// 3. `hasEnded` → completed
  /// 4. それ以外 → active
  WeeklyQuestProgress evaluate({
    required WeeklyQuest quest,
    required List<ExpenseEntry> entries,
    required WeeklyQuestPeriod period,
    required DateTime now,
    WeeklyQuestStatus baseStatus = WeeklyQuestStatus.active,
  }) {
    final spent = spentFor(quest: quest, entries: entries, period: period);
    final ended = period.hasEnded(now);
    final status = _resolveStatus(
      baseStatus: baseStatus,
      spentAmount: spent,
      budgetLimit: quest.budgetLimit,
      hasEnded: ended,
    );
    return WeeklyQuestProgress(
      quest: quest,
      spentAmount: spent,
      remainingDays: period.remainingDays(now),
      hasEnded: ended,
      status: status,
    );
  }

  /// 複数クエストをまとめて評価する（入力順を保つ）。
  List<WeeklyQuestProgress> evaluateAll({
    required List<WeeklyQuest> quests,
    required List<ExpenseEntry> entries,
    required WeeklyQuestPeriod period,
    required DateTime now,
    WeeklyQuestStatus baseStatus = WeeklyQuestStatus.active,
  }) {
    return quests
        .map((quest) => evaluate(
              quest: quest,
              entries: entries,
              period: period,
              now: now,
              baseStatus: baseStatus,
            ))
        .toList();
  }

  static WeeklyQuestStatus _resolveStatus({
    required WeeklyQuestStatus baseStatus,
    required int spentAmount,
    required int budgetLimit,
    required bool hasEnded,
  }) {
    if (baseStatus == WeeklyQuestStatus.pending) {
      return WeeklyQuestStatus.pending;
    }
    if (spentAmount > budgetLimit) return WeeklyQuestStatus.failed;
    if (hasEnded) return WeeklyQuestStatus.completed;
    return WeeklyQuestStatus.active;
  }
}
