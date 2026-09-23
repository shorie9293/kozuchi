import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/features/calendar/domain/calendar_service.dart';

ExpenseEntry entry(
  String id,
  int amount,
  DateTime date,
) =>
    ExpenseEntry(id: id, amount: amount, category: '食費', date: date);

/// amount を 0 に差し替えたテスト用サブクラス（service のフィルタ検証用）
class _ZeroAmount extends ExpenseEntry {
  _ZeroAmount(ExpenseEntry base)
      : super(
          id: base.id,
          amount: base.amount,
          category: base.category,
          date: base.date,
        );

  @override
  int get amount => 0;
}

void main() {
  const service = CalendarService();

  group('CalendarService.build', () {
    test('月内 entry が日別に集約され days が全日数そろう', () {
      final cal = service.build(
        entries: [
          entry('a', 300, DateTime(2026, 9, 5, 10)),
          entry('b', 200, DateTime(2026, 9, 5, 9)),
          entry('c', 500, DateTime(2026, 9, 20)),
        ],
        year: 2026,
        month: 9,
      );
      expect(cal.daysInMonth, 30);
      expect(cal.totalAmount, 1000);
      expect(cal.spendingDayCount, 2);
      final d5 = cal.summaryFor(5);
      expect(d5.totalAmount, 500);
      expect(d5.entries.map((e) => e.id).toList(), ['b', 'a']);
      expect(cal.summaryFor(1).totalAmount, 0);
      expect(cal.summaryFor(1).isEmpty, isTrue);
    });

    test('月外 entry は無視される', () {
      final cal = service.build(
        entries: [
          entry('in', 100, DateTime(2026, 9, 15)),
          entry('prev', 999, DateTime(2026, 8, 31)),
          entry('next', 999, DateTime(2026, 10, 1)),
        ],
        year: 2026,
        month: 9,
      );
      expect(cal.totalAmount, 100);
      expect(cal.spendingDayCount, 1);
    });

    test('amount <= 0 の entry は無視される', () {
      // ExpenseEntry 本体は assert(amount > 0) のため、
      // サブクラスで getter を差し替えて service 側のフィルタを検証する
      final zero = _ZeroAmount(entry('zero', 100, DateTime(2026, 9, 16)));
      final neg = _ZeroAmount(entry('neg', 100, DateTime(2026, 9, 17)));
      expect(zero.amount, 0);
      final cal = service.build(
        entries: [
          entry('ok', 100, DateTime(2026, 9, 15)),
          zero,
          neg,
        ],
        year: 2026,
        month: 9,
      );
      expect(cal.totalAmount, 100);
      expect(cal.spendingDayCount, 1);
    });

    test('入力リストは非破壊', () {
      final entries = [
        entry('b', 100, DateTime(2026, 9, 5, 12)),
        entry('a', 100, DateTime(2026, 9, 5, 12)),
      ];
      final orderBefore = entries.map((e) => e.id).toList();
      service.build(entries: entries, year: 2026, month: 9);
      expect(entries.map((e) => e.id).toList(), orderBefore);
    });

    test('支出なしの月は全日 totalAmount 0・isEmpty true・maxDay null', () {
      final cal = service.build(entries: const [], year: 2026, month: 9);
      expect(cal.daysInMonth, 30);
      expect(cal.totalAmount, 0);
      expect(cal.isEmpty, isTrue);
      expect(cal.maxDay, isNull);
    });
  });

  group('CalendarService.shiftMonth', () {
    test('12月+1 → 翌年1月', () {
      expect(service.shiftMonth(year: 2026, month: 12, deltaMonths: 1),
          (year: 2027, month: 1));
    });

    test('1月-1 → 前年12月', () {
      expect(service.shiftMonth(year: 2026, month: 1, deltaMonths: -1),
          (year: 2025, month: 12));
    });

    test('deltaMonths 0 は同値', () {
      expect(service.shiftMonth(year: 2026, month: 9, deltaMonths: 0),
          (year: 2026, month: 9));
    });

    test('複数月跨ぎ（3月-5 → 前年10月）', () {
      expect(service.shiftMonth(year: 2026, month: 3, deltaMonths: -5),
          (year: 2025, month: 10));
    });

    test('month が 1..12 外なら ArgumentError', () {
      expect(
        () => service.shiftMonth(year: 2026, month: 0, deltaMonths: 1),
        throwsArgumentError,
      );
      expect(
        () => service.shiftMonth(year: 2026, month: 13, deltaMonths: 1),
        throwsArgumentError,
      );
    });
  });

  group('CalendarService.isCurrentMonth', () {
    test('同じ年月なら true', () {
      expect(
        service.isCurrentMonth(
          year: 2026,
          month: 9,
          now: DateTime(2026, 9, 23, 15),
        ),
        isTrue,
      );
    });

    test('年が違えば false', () {
      expect(
        service.isCurrentMonth(
          year: 2025,
          month: 9,
          now: DateTime(2026, 9, 23),
        ),
        isFalse,
      );
    });

    test('月が違えば false', () {
      expect(
        service.isCurrentMonth(
          year: 2026,
          month: 8,
          now: DateTime(2026, 9, 23),
        ),
        isFalse,
      );
    });
  });

  group('MonthCalendar と CalendarService の統合', () {
    test('build 結果から weeks/weeklyTotals が構築できる', () {
      final cal = service.build(
        entries: [
          entry('a', 100, DateTime(2026, 9, 1)),
          entry('b', 200, DateTime(2026, 9, 30)),
        ],
        year: 2026,
        month: 9,
      );
      expect(cal.weeks.length, 5);
      expect(cal.weeklyTotals.length, 5);
      expect(cal.weeklyTotals.reduce((a, b) => a + b), 300);
    });
  });
}