import '../../../domain/models/expense_entry.dart';
import 'day_expense_summary.dart';
import 'month_calendar.dart';

/// 取引カレンダーを構築するサービス
///
/// 純粋ロジックのみ。now は引数注入（DateTime.now() を内部で呼ばない）。
class CalendarService {
  const CalendarService();

  /// [entries] から [year] 年 [month] 月のカレンダーを構築する
  ///
  /// 対象年月外の entry は無視。amount <= 0 も無視。
  /// 日内 entries は date 昇順 → 同時刻 id 昇順（DayExpenseSummary がソート）。
  /// 入力リストは非破壊。
  MonthCalendar build({
    required List<ExpenseEntry> entries,
    required int year,
    required int month,
  }) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final filtered = entries
        .where((e) =>
            e.amount > 0 &&
            e.date.year == year &&
            e.date.month == month)
        .toList();

    final days = List.generate(daysInMonth, (i) {
      final day = DateTime(year, month, i + 1);
      final dayEntries = filtered
          .where((e) =>
              e.date.year == year && e.date.month == month && e.date.day == i + 1)
          .toList();
      return DayExpenseSummary(
        date: day,
        totalAmount: dayEntries.fold(0, (sum, e) => sum + e.amount),
        entries: dayEntries,
      );
    }, growable: false);

    return MonthCalendar(year: year, month: month, days: days);
  }

  /// 月をずらす。12月+1 → 翌年1月、1月-1 → 前年12月。
  ({int year, int month}) shiftMonth({
    required int year,
    required int month,
    required int deltaMonths,
  }) {
    if (month < 1 || month > 12) {
      throw ArgumentError('month must be 1..12, was $month');
    }
    final total = year * 12 + (month - 1) + deltaMonths;
    return (year: total ~/ 12, month: total % 12 + 1);
  }

  /// [now] が [year] 年 [month] 月か
  bool isCurrentMonth({
    required int year,
    required int month,
    required DateTime now,
  }) =>
      now.year == year && now.month == month;
}
