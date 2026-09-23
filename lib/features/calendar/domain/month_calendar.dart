import 'day_expense_summary.dart';

/// 一か月分のカレンダー
///
/// [days] はその月の 1..daysInMonth を昇順で全件含む（支出なしは totalAmount 0）。
class MonthCalendar {
  final int year;

  /// 1..12
  final int month;

  final List<DayExpenseSummary> days;

  MonthCalendar({required this.year, required this.month, required List<DayExpenseSummary> days})
      : days = List.unmodifiable(days) {
    if (month < 1 || month > 12) {
      throw ArgumentError('month must be 1..12, was $month');
    }
    if (days.length != daysInMonth) {
      throw ArgumentError(
        'days must contain all $daysInMonth days of $year-$month, got ${days.length}',
      );
    }
    for (var i = 0; i < days.length; i++) {
      final expected = DateTime(year, month, i + 1);
      if (days[i].date != expected) {
        throw ArgumentError(
          'days[$i] is ${days[i].date}, expected $expected',
        );
      }
    }
  }

  /// その月の日数
  int get daysInMonth => DateTime(year, month + 1, 0).day;

  /// 1日の曜日を日曜始まりで 0..6
  int get leadingBlanks => DateTime(year, month, 1).weekday % 7;

  /// days の totalAmount 合計
  int get totalAmount =>
      days.fold(0, (sum, day) => sum + day.totalAmount);

  /// 支出のある日数
  int get spendingDayCount =>
      days.where((day) => day.entryCount > 0).length;

  /// 支出が 1 日もないか
  bool get isEmpty => spendingDayCount == 0;

  /// totalAmount 最大の日。同額なら日付が早い方。全 0 なら null。
  DayExpenseSummary? get maxDay {
    DayExpenseSummary? best;
    for (final day in days) {
      if (day.totalAmount == 0) continue;
      if (best == null || day.totalAmount > best.totalAmount) {
        best = day;
      }
    }
    return best;
  }

  /// '2026年9月' 形式のタイトル（月は先頭 0 なし）
  String get title => '$year年$month月';

  /// 日曜始まりの週分割。各行 7 要素・空白は null。
  List<List<DayExpenseSummary?>> get weeks {
    final rows = ((leadingBlanks + daysInMonth) / 7).ceil();
    final result = List.generate(
      rows,
      (_) => List<DayExpenseSummary?>.filled(7, null, growable: false),
      growable: false,
    );
    for (var d = 0; d < days.length; d++) {
      final index = leadingBlanks + d;
      result[index ~/ 7][index % 7] = days[d];
    }
    return result;
  }

  /// weeks と同数の各行合計
  List<int> get weeklyTotals => weeks
      .map((week) => week
          .whereType<DayExpenseSummary>()
          .fold(0, (sum, day) => sum + day.totalAmount))
      .toList(growable: false);

  /// [day] 日のサマリ。範囲外は ArgumentError。
  DayExpenseSummary summaryFor(int day) {
    if (day < 1 || day > daysInMonth) {
      throw ArgumentError('day must be 1..$daysInMonth, was $day');
    }
    return days[day - 1];
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MonthCalendar || runtimeType != other.runtimeType) {
      return false;
    }
    if (year != other.year || month != other.month) return false;
    if (days.length != other.days.length) return false;
    for (var i = 0; i < days.length; i++) {
      final mine = days[i];
      final theirs = other.days[i];
      if (mine.date != theirs.date || mine.totalAmount != theirs.totalAmount) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        year,
        month,
        Object.hashAll(days.map((d) => Object.hash(d.date, d.totalAmount))),
      );

  @override
  String toString() => 'MonthCalendar($title, totalAmount: $totalAmount)';
}
