import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/monthly_report/domain/monthly_report_period.dart';

void main() {
  group('MonthlyReportPeriod', () {
    test('month が 0 以下なら ArgumentError', () {
      expect(
        () => MonthlyReportPeriod(year: 2026, month: 0),
        throwsArgumentError,
      );
    });

    test('month が 13 以上なら ArgumentError', () {
      expect(
        () => MonthlyReportPeriod(year: 2026, month: 13),
        throwsArgumentError,
      );
    });

    test('year が 1970 未満なら ArgumentError', () {
      expect(
        () => MonthlyReportPeriod(year: 1969, month: 1),
        throwsArgumentError,
      );
    });

    test('fromDate は年月を取り出す', () {
      final period = MonthlyReportPeriod.fromDate(DateTime(2026, 9, 15, 21, 30));
      expect(period.year, 2026);
      expect(period.month, 9);
    });

    test('start は月初0時', () {
      final period = MonthlyReportPeriod(year: 2026, month: 9);
      expect(period.start, DateTime(2026, 9, 1));
    });

    test('end は月末日（31日月）', () {
      expect(
        MonthlyReportPeriod(year: 2026, month: 1).end,
        DateTime(2026, 1, 31),
      );
    });

    test('end は月末日（30日月）', () {
      expect(
        MonthlyReportPeriod(year: 2026, month: 4).end,
        DateTime(2026, 4, 30),
      );
    });

    test('end は月末日（平年2月）', () {
      expect(
        MonthlyReportPeriod(year: 2026, month: 2).end,
        DateTime(2026, 2, 28),
      );
    });

    test('end は月末日（閏年2月）', () {
      expect(
        MonthlyReportPeriod(year: 2028, month: 2).end,
        DateTime(2028, 2, 29),
      );
    });

    test('end は月末日（12月）', () {
      expect(
        MonthlyReportPeriod(year: 2026, month: 12).end,
        DateTime(2026, 12, 31),
      );
    });

    test('previous は前月', () {
      expect(
        MonthlyReportPeriod(year: 2026, month: 9).previous,
        MonthlyReportPeriod(year: 2026, month: 8),
      );
    });

    test('previous は年を跨ぐ（1月→前年12月）', () {
      expect(
        MonthlyReportPeriod(year: 2026, month: 1).previous,
        MonthlyReportPeriod(year: 2025, month: 12),
      );
    });

    test('next は翌月', () {
      expect(
        MonthlyReportPeriod(year: 2026, month: 9).next,
        MonthlyReportPeriod(year: 2026, month: 10),
      );
    });

    test('next は年を跨ぐ（12月→翌年1月）', () {
      expect(
        MonthlyReportPeriod(year: 2026, month: 12).next,
        MonthlyReportPeriod(year: 2027, month: 1),
      );
    });

    test('contains は同月の日付で true（時刻は無視）', () {
      final period = MonthlyReportPeriod(year: 2026, month: 9);
      expect(period.contains(DateTime(2026, 9, 15, 23, 59)), isTrue);
      expect(period.contains(DateTime(2026, 9, 1)), isTrue);
      expect(period.contains(DateTime(2026, 9, 30)), isTrue);
    });

    test('contains は前月末日・翌月1日で false', () {
      final period = MonthlyReportPeriod(year: 2026, month: 9);
      expect(period.contains(DateTime(2026, 8, 31)), isFalse);
      expect(period.contains(DateTime(2026, 10, 1)), isFalse);
      expect(period.contains(DateTime(2025, 9, 15)), isFalse);
    });

    test('label は 2026年9月 形式（ゼロ埋めなし）', () {
      expect(MonthlyReportPeriod(year: 2026, month: 9).label, '2026年9月');
      expect(MonthlyReportPeriod(year: 2026, month: 12).label, '2026年12月');
    });

    test('等価性と hashCode', () {
      final a = MonthlyReportPeriod(year: 2026, month: 9);
      final b = MonthlyReportPeriod(year: 2026, month: 9);
      final c = MonthlyReportPeriod(year: 2026, month: 10);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    test('toString は年月を含む', () {
      expect(
        MonthlyReportPeriod(year: 2026, month: 9).toString(),
        contains('2026-9'),
      );
    });
  });
}
