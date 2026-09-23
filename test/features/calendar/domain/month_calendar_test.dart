import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/features/calendar/domain/day_expense_summary.dart';
import 'package:kozuchi/features/calendar/domain/month_calendar.dart';

DayExpenseSummary daySummary(
  int day, {
  int amount = 0,
  List<ExpenseEntry> entries = const [],
}) {
  final date = DateTime(2026, 9, day);
  final realEntries = entries.isNotEmpty && amount > 0
      ? entries
      : amount > 0
          ? [
              ExpenseEntry(
                id: 'e$day',
                amount: amount,
                category: '食費',
                date: date,
              ),
            ]
          : const <ExpenseEntry>[];
  return DayExpenseSummary(
    date: date,
    totalAmount: amount,
    entries: realEntries,
  );
}

MonthCalendar buildMonth({
  int year = 2026,
  int month = 9,
  required List<DayExpenseSummary> days,
}) =>
    MonthCalendar(year: year, month: month, days: days);

void main() {
  group('MonthCalendar 検証', () {
    test('month が 1..12 外なら ArgumentError', () {
      expect(
        () => buildMonth(month: 0, days: const []),
        throwsArgumentError,
      );
      expect(
        () => buildMonth(month: 13, days: const []),
        throwsArgumentError,
      );
    });

    test('days がその月の全日数と一致しなければ ArgumentError', () {
      final days = List.generate(29, (i) => daySummary(i + 1)); // 9月は30日
      expect(() => buildMonth(days: days), throwsArgumentError);
    });
  });

  group('MonthCalendar 月構造', () {
    test('daysInMonth（2026年9月=30日・2026年2月=28日）', () {
      final sep = buildMonth(days: List.generate(30, (i) => daySummary(i + 1)));
      expect(sep.daysInMonth, 30);
      final feb = MonthCalendar(
        year: 2026,
        month: 2,
        days: List.generate(28, (i) => DayExpenseSummary(
              date: DateTime(2026, 2, i + 1),
              totalAmount: 0,
              entries: const [],
            )),
      );
      expect(feb.daysInMonth, 28);
    });

    test('leadingBlanks: 月初が日曜なら 0（2026年2月1日は日曜）', () {
      final feb = MonthCalendar(
        year: 2026,
        month: 2,
        days: List.generate(28, (i) => DayExpenseSummary(
              date: DateTime(2026, 2, i + 1),
              totalAmount: 0,
              entries: const [],
            )),
      );
      expect(DateTime(2026, 2, 1).weekday, DateTime.sunday);
      expect(feb.leadingBlanks, 0);
    });

    test('leadingBlanks: 月初が土曜なら 6（2026年8月1日は土曜）', () {
      expect(DateTime(2026, 8, 1).weekday, DateTime.saturday);
      final aug = MonthCalendar(
        year: 2026,
        month: 8,
        days: List.generate(31, (i) => DayExpenseSummary(
              date: DateTime(2026, 8, i + 1),
              totalAmount: 0,
              entries: const [],
            )),
      );
      expect(aug.leadingBlanks, 6);
    });

    test('totalAmount は days の合計', () {
      final days = List.generate(30, (i) => daySummary(i + 1, amount: i < 3 ? 100 : 0));
      expect(buildMonth(days: days).totalAmount, 300);
    });

    test('spendingDayCount / isEmpty', () {
      final days = List.generate(30, (i) => daySummary(i + 1, amount: i < 2 ? 100 : 0));
      final cal = buildMonth(days: days);
      expect(cal.spendingDayCount, 2);
      expect(cal.isEmpty, isFalse);

      final empty = buildMonth(days: List.generate(30, (i) => daySummary(i + 1)));
      expect(empty.spendingDayCount, 0);
      expect(empty.isEmpty, isTrue);
    });

    test('maxDay: 最大日を返す。同額なら日付が早い方。全0なら null', () {
      final days = List.generate(30, (i) {
        final d = i + 1;
        return daySummary(d, amount: d == 10 ? 500 : d == 20 ? 300 : 0);
      });
      expect(buildMonth(days: days).maxDay?.date.day, 10);

      final tie = List.generate(30, (i) {
        final d = i + 1;
        return daySummary(d, amount: d == 5 || d == 15 ? 400 : 0);
      });
      expect(buildMonth(days: tie).maxDay?.date.day, 5);

      final allZero = buildMonth(days: List.generate(30, (i) => daySummary(i + 1)));
      expect(allZero.maxDay, isNull);
    });

    test('title が 2026年9月 形式（月は先頭0なし）', () {
      expect(buildMonth(days: List.generate(30, (i) => daySummary(i + 1))).title,
          '2026年9月');
      final jan = MonthCalendar(
        year: 2026,
        month: 1,
        days: List.generate(31, (i) => DayExpenseSummary(
              date: DateTime(2026, 1, i + 1),
              totalAmount: 0,
              entries: const [],
            )),
      );
      expect(jan.title, '2026年1月');
    });
  });

  group('MonthCalendar weeks / weeklyTotals', () {
    test('weeks: 7要素×必要行数、空白は null（2026年9月: leadingBlanks=2）', () {
      final cal = buildMonth(days: List.generate(30, (i) => daySummary(i + 1)));
      // 2026-09-01 は火曜 → weekday 2 → blanks 2
      expect(cal.leadingBlanks, 2);
      final weeks = cal.weeks;
      final expectedRows = ((cal.leadingBlanks + cal.daysInMonth) / 7).ceil();
      expect(weeks.length, expectedRows);
      for (final week in weeks) {
        expect(week.length, 7);
      }
      expect(weeks[0][0], isNull);
      expect(weeks[0][1], isNull);
      expect(weeks[0][2]?.date.day, 1);
      expect(weeks.last[0]?.date.day, 27);
      expect(weeks.last[3]?.date.day, 30);
      expect(weeks.last[4], isNull);
      expect(weeks.last[6], isNull);
    });

    test('weeklyTotals が weeks と同数で各行の合計に整合', () {
      final days = List.generate(30, (i) {
        final d = i + 1;
        return daySummary(d, amount: d == 1 ? 100 : d == 8 ? 200 : 0);
      });
      final cal = buildMonth(days: days);
      expect(cal.weeklyTotals.length, cal.weeks.length);
      for (var i = 0; i < cal.weeks.length; i++) {
        final sum = cal.weeks[i]
            .whereType<DayExpenseSummary>()
            .fold(0, (acc, d) => acc + d.totalAmount);
        expect(cal.weeklyTotals[i], sum);
      }
      // 1日(火曜=行0) と 8日(行1) の合計
      expect(cal.weeklyTotals[0], 100);
      expect(cal.weeklyTotals[1], 200);
    });
  });

  group('MonthCalendar summaryFor / 等価性', () {
    test('summaryFor: 範囲内は該当日、範囲外は ArgumentError', () {
      final cal = buildMonth(days: List.generate(30, (i) => daySummary(i + 1)));
      expect(cal.summaryFor(1).date, DateTime(2026, 9, 1));
      expect(cal.summaryFor(30).date, DateTime(2026, 9, 30));
      expect(() => cal.summaryFor(0), throwsArgumentError);
      expect(() => cal.summaryFor(31), throwsArgumentError);
    });

    test('== は year/month/days（日付とtotalAmountの組）で比較', () {
      final a = buildMonth(days: List.generate(30, (i) => daySummary(i + 1, amount: i == 0 ? 100 : 0)));
      final b = buildMonth(days: List.generate(30, (i) => daySummary(i + 1, amount: i == 0 ? 100 : 0)));
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);

      final c = buildMonth(days: List.generate(30, (i) => daySummary(i + 1, amount: i == 0 ? 200 : 0)));
      expect(a == c, isFalse);
      final d = buildMonth(year: 2026, month: 8, days: List.generate(31, (i) => DayExpenseSummary(
            date: DateTime(2026, 8, i + 1),
            totalAmount: 0,
            entries: const [],
          )));
      expect(a == d, isFalse);
    });
  });
}