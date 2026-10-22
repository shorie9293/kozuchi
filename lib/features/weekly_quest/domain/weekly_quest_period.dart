/// 週次クエストの対象週（月曜 00:00 始まり、日曜終わり）。
///
/// すべて**ローカル日付**で計算する。UTC と JST が混在すると週境界が
/// 1日ずれるため、日付比較は「年月日のみ」の数値計算に落として行う。
class WeeklyQuestPeriod {
  /// ローカル時刻の月曜 00:00。
  final DateTime weekStart;

  const WeeklyQuestPeriod({required this.weekStart});

  /// [now] を含む週の [WeeklyQuestPeriod] を作る。
  ///
  /// 月曜正規化: `DateTime(y, m, d) - (weekday - 1)日`。
  /// Duration 減算は DST で 23:00 になり得るため、最後に年月日で組み直す。
  factory WeeklyQuestPeriod.of(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: now.weekday - 1));
    return WeeklyQuestPeriod(
      weekStart: DateTime(monday.year, monday.month, monday.day),
    );
  }

  /// 翌週月曜 00:00（排他的終端）。
  DateTime get weekEndExclusive =>
      DateTime(weekStart.year, weekStart.month, weekStart.day + 7);

  /// 週の識別子 `'YYYY-MM-DD'`（weekStart の日付。ゼロ埋め）。
  String get weekKey =>
      '${_pad(weekStart.year, 4)}-${_pad(weekStart.month, 2)}-${_pad(weekStart.day, 2)}';

  /// 表示用ラベル 例: `'10/19(月)〜10/25(日)'`。
  String get label {
    final end = _addDays(weekStart, 6);
    return '${weekStart.month}/${weekStart.day}(${_weekdayLabel(weekStart)})'
        '〜${end.month}/${end.day}(${_weekdayLabel(end)})';
  }

  /// [when] が週内（weekStart <= when < weekEndExclusive）か。
  bool contains(DateTime when) =>
      !when.isBefore(weekStart) && when.isBefore(weekEndExclusive);

  /// 週が終了しているか。
  bool hasEnded(DateTime now) => !now.isBefore(weekEndExclusive);

  /// 残り日数（0..7）。週終了後は 0、週開始前は 7。
  int remainingDays(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final diff = _daysBetween(today, weekEndExclusive);
    if (diff < 0) return 0;
    if (diff > 7) return 7;
    return diff;
  }

  /// [now] がこの週と同じ週か。
  bool isSameWeek(DateTime now) =>
      weekKey == WeeklyQuestPeriod.of(now).weekKey;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeeklyQuestPeriod && weekStart == other.weekStart;

  @override
  int get hashCode => weekStart.hashCode;

  @override
  String toString() => 'WeeklyQuestPeriod($weekKey, $label)';

  // ------------------------------------------------------------
  //  内部ヘルパー（ローカル日付ベース）
  // ------------------------------------------------------------

  static String _pad(int value, int width) =>
      value.toString().padLeft(width, '0');

  static String _weekdayLabel(DateTime date) {
    const labels = ['月', '火', '水', '木', '金', '土', '日'];
    final index = date.weekday - 1;
    if (index < 0 || index >= labels.length) return '';
    return labels[index];
  }

  static DateTime _addDays(DateTime date, int days) =>
      DateTime(date.year, date.month, date.day + days);

  /// 年月日のみの差分（DST の影響を受けないよう UTC で日付を比較する）。
  static int _daysBetween(DateTime from, DateTime to) {
    final a = DateTime.utc(from.year, from.month, from.day);
    final b = DateTime.utc(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }
}
