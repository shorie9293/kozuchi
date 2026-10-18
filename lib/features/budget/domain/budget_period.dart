/// 家計の「締め日」を考慮した集計期間（純粋 Dart / Flutter 非依存）。
///
/// 締め日 [closingDay] は 1〜28 に正規化済みの値で、1 は暦月（従来挙動）、
/// 2 以上は「前月 (closingDay+1) 日〜当月 closingDay 日」を 1 期間とする。
/// 期間は [start] と [end] の両端の日を含み、いずれも時刻 00:00 のローカル日付。
class BudgetPeriod {
  /// 正規化済みの締め日（1〜28）。
  final int closingDay;

  /// 期間の初日 00:00（この日を含む）。
  final DateTime start;

  /// 期間の最終日 00:00（この日を含む）。
  final DateTime end;

  const BudgetPeriod({
    required this.closingDay,
    required this.start,
    required this.end,
  });

  /// 期間の日数（両端を含む）。
  ///
  /// ローカル時刻の差は夏時間などで 1 日ずれ得るため、
  /// 年月日だけを取り出した UTC 値で日数を数える。
  int get days =>
      DateTime.utc(end.year, end.month, end.day)
          .difference(DateTime.utc(start.year, start.month, start.day))
          .inDays +
      1;

  /// [date] がこの期間に含まれるか。時刻は無視して日単位で比較する。
  bool contains(DateTime date) {
    final target = DateTime(date.year, date.month, date.day);
    return !target.isBefore(start) && !target.isAfter(end);
  }

  /// 表示用ラベル（例: '2026/09/26 〜 2026/10/25'）。
  String get label => '${_format(start)} 〜 ${_format(end)}';

  /// 同じ締め日で 1 期間前。
  ///
  /// 日付の引き算ではなく [BudgetPeriodService.periodFor] の意味論で再計算するため、
  /// 月末日数の差（31日/30日/2月）でずれない。
  BudgetPeriod get previous => BudgetPeriodService.periodFor(
        DateTime(start.year, start.month, start.day - 1),
        closingDay: closingDay,
      );

  /// 同じ締め日で 1 期間後。[previous] と同様に再計算する。
  BudgetPeriod get next => BudgetPeriodService.periodFor(
        DateTime(end.year, end.month, end.day + 1),
        closingDay: closingDay,
      );

  static String _format(DateTime d) =>
      '${d.year}/${_two(d.month)}/${_two(d.day)}';

  static String _two(int value) => value.toString().padLeft(2, '0');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BudgetPeriod &&
          other.closingDay == closingDay &&
          other.start == start &&
          other.end == end;

  @override
  int get hashCode => Object.hash(closingDay, start, end);

  @override
  String toString() =>
      'BudgetPeriod(closingDay: $closingDay, start: ${_iso(start)}, end: ${_iso(end)})';

  static String _iso(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';
}

/// 締め日から集計期間を導出するサービス。
class BudgetPeriodService {
  /// 既定の締め日。1 は暦月（1日〜末日）＝従来挙動。
  static const int defaultClosingDay = 1;

  /// 締め日の下限。
  static const int minClosingDay = 1;

  /// 締め日の上限。29〜31 を許すと 2 月で期間が壊れるため 28 までとする。
  static const int maxClosingDay = 28;

  /// 締め日を 1〜28 に正規化する。範囲外・0 以下は [defaultClosingDay] へ倒す。
  static int normalize(int day) {
    if (day < minClosingDay || day > maxClosingDay) return defaultClosingDay;
    return day;
  }

  /// [reference] を含む集計期間を返す。
  ///
  /// - [closingDay] == 1: 暦月（月初〜末日）。従来の月初固定と完全一致する。
  /// - [closingDay] >= 2:
  ///   - reference.day > closingDay なら「当月 closingDay+1 日〜翌月 closingDay 日」
  ///   - そうでなければ「前月 closingDay+1 日〜当月 closingDay 日」
  ///
  /// start/end は必ず時刻 00:00、end は締め日当日を含む。
  static BudgetPeriod periodFor(
    DateTime reference, {
    int closingDay = defaultClosingDay,
  }) {
    final cd = normalize(closingDay);
    final y = reference.year;
    final m = reference.month;

    // 暦月: 月初〜末日。従来の getMonthlySummary と同一の期間になる。
    if (cd == 1) {
      return BudgetPeriod(
        closingDay: 1,
        start: DateTime(y, m, 1),
        end: DateTime(y, m + 1, 0),
      );
    }

    final DateTime start;
    final DateTime end;
    if (reference.day > cd) {
      // 締め日を過ぎている → 当月 closingDay+1 日〜翌月 closingDay 日
      end = DateTime(y, m + 1, cd);
      start = DateTime(y, m, cd + 1);
    } else {
      // 締め日以前 → 前月 closingDay+1 日〜当月 closingDay 日
      end = DateTime(y, m, cd);
      start = DateTime(y, m - 1, cd + 1);
    }

    return BudgetPeriod(closingDay: cd, start: start, end: end);
  }

  /// 締め日の説明文（例: 1 → '毎月末日締め'、25 → '毎月25日締め'）。
  static String closingDayLabel(int closingDay) {
    final cd = normalize(closingDay);
    if (cd == 1) return '毎月末日締め';
    return '毎月$cd日締め';
  }

  /// 期間の説明文（例: 1 → '暦月（1日〜末日）'、25 → '前月26日〜当月25日'）。
  static String transitionLabel(int closingDay) {
    final cd = normalize(closingDay);
    if (cd == 1) return '暦月（1日〜末日）';
    final startDay = cd + 1;
    return '前月$startDay日〜当月$cd日';
  }
}
