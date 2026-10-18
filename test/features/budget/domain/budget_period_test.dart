import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/budget/domain/budget_period.dart';

/// ローカル時刻の年月日 00:00 を組み立てるヘルパー。
///
/// 実装側も `DateTime(y, m, d)` でローカル時刻を組むため、
/// タイムゾーンに依存せず期待値と比較できる。
DateTime day(int year, int month, int dayOfMonth) =>
    DateTime(year, month, dayOfMonth);

void main() {
  group('BudgetPeriodService.periodFor: closingDay=1 は暦月', () {
    test('月中の日付は月初〜月末になる', () {
      final p = BudgetPeriodService.periodFor(day(2026, 6, 15));
      expect(p.closingDay, 1);
      expect(p.start, day(2026, 6, 1));
      expect(p.end, day(2026, 6, 30));
    });

    test('31日まである月', () {
      final p = BudgetPeriodService.periodFor(day(2026, 1, 15));
      expect(p.start, day(2026, 1, 1));
      expect(p.end, day(2026, 1, 31));
    });

    test('平年2月は28日まで', () {
      final p = BudgetPeriodService.periodFor(day(2026, 2, 15));
      expect(p.start, day(2026, 2, 1));
      expect(p.end, day(2026, 2, 28));
    });

    test('閏年2月は29日まで', () {
      final p = BudgetPeriodService.periodFor(day(2024, 2, 10));
      expect(p.start, day(2024, 2, 1));
      expect(p.end, day(2024, 2, 29));
    });

    test('12月は31日まで', () {
      final p = BudgetPeriodService.periodFor(day(2025, 12, 5));
      expect(p.start, day(2025, 12, 1));
      expect(p.end, day(2025, 12, 31));
    });

    test('月初日・月末日も同じ暦月に属する', () {
      final first = BudgetPeriodService.periodFor(day(2026, 6, 1));
      final last = BudgetPeriodService.periodFor(day(2026, 6, 30));
      expect(first.start, day(2026, 6, 1));
      expect(first.end, day(2026, 6, 30));
      expect(last.start, day(2026, 6, 1));
      expect(last.end, day(2026, 6, 30));
      expect(first, equals(last));
    });

    test('start/end は必ず 00:00:00.000', () {
      final p = BudgetPeriodService.periodFor(day(2026, 6, 15));
      for (final d in [p.start, p.end]) {
        expect(d.hour, 0);
        expect(d.minute, 0);
        expect(d.second, 0);
        expect(d.millisecond, 0);
        expect(d.microsecond, 0);
      }
    });

    test('参照日が時刻付きでも暦月は変わらない', () {
      final p =
          BudgetPeriodService.periodFor(DateTime(2026, 6, 30, 23, 59, 59));
      expect(p.start, day(2026, 6, 1));
      expect(p.end, day(2026, 6, 30));
    });
  });

  group('BudgetPeriodService.periodFor: closingDay=25 の境界', () {
    test('2026-11-01 は 10/26〜11/25', () {
      final p = BudgetPeriodService.periodFor(day(2026, 11, 1), closingDay: 25);
      expect(p.closingDay, 25);
      expect(p.start, day(2026, 10, 26));
      expect(p.end, day(2026, 11, 25));
    });

    test('2026-11-25（締め日当日）も同じ期間', () {
      final p =
          BudgetPeriodService.periodFor(day(2026, 11, 25), closingDay: 25);
      expect(p.start, day(2026, 10, 26));
      expect(p.end, day(2026, 11, 25));
    });

    test('2026-11-26（締め日翌日）は次の期間', () {
      final p =
          BudgetPeriodService.periodFor(day(2026, 11, 26), closingDay: 25);
      expect(p.start, day(2026, 11, 26));
      expect(p.end, day(2026, 12, 25));
    });

    test('2026-10-26 は 11月分の期間に属する', () {
      final p =
          BudgetPeriodService.periodFor(day(2026, 10, 26), closingDay: 25);
      expect(p.start, day(2026, 10, 26));
      expect(p.end, day(2026, 11, 25));
    });

    test('2026-10-25 は 9/26〜10/25 の期間', () {
      final p =
          BudgetPeriodService.periodFor(day(2026, 10, 25), closingDay: 25);
      expect(p.start, day(2026, 9, 26));
      expect(p.end, day(2026, 10, 25));
    });

    test('年を跨ぐ締め日（closingDay=5, 2026-01-03）', () {
      final p = BudgetPeriodService.periodFor(day(2026, 1, 3), closingDay: 5);
      expect(p.start, day(2025, 12, 6));
      expect(p.end, day(2026, 1, 5));
    });

    test('年を跨ぐ締め日（closingDay=5, 2026-01-06）', () {
      final p = BudgetPeriodService.periodFor(day(2026, 1, 6), closingDay: 5);
      expect(p.start, day(2026, 1, 6));
      expect(p.end, day(2026, 2, 5));
    });

    test('範囲外の closingDay は暦月へ正規化される', () {
      final p = BudgetPeriodService.periodFor(day(2026, 6, 15), closingDay: 99);
      expect(p.closingDay, 1);
      expect(p.start, day(2026, 6, 1));
      expect(p.end, day(2026, 6, 30));
    });
  });

  group('BudgetPeriod.contains は日単位で判定する', () {
    final p = BudgetPeriodService.periodFor(day(2026, 11, 1), closingDay: 25);

    test('開始日当日は true', () {
      expect(p.contains(day(2026, 10, 26)), isTrue);
    });

    test('開始日前日は false', () {
      expect(p.contains(day(2026, 10, 25)), isFalse);
    });

    test('終了日当日は true', () {
      expect(p.contains(day(2026, 11, 25)), isTrue);
    });

    test('終了日の翌日は false', () {
      expect(p.contains(day(2026, 11, 26)), isFalse);
    });

    test('時刻付きでも日単位で判定する', () {
      expect(p.contains(DateTime(2026, 10, 26, 0, 0, 1)), isTrue);
      expect(p.contains(DateTime(2026, 11, 25, 23, 59, 59)), isTrue);
      expect(p.contains(DateTime(2026, 11, 26, 0, 0, 0)), isFalse);
      expect(p.contains(DateTime(2026, 10, 25, 23, 59, 59)), isFalse);
    });
  });

  group('BudgetPeriod.days / label / 等価性', () {
    test('2026/09/26〜2026/10/25 は 30日', () {
      final p =
          BudgetPeriodService.periodFor(day(2026, 10, 25), closingDay: 25);
      expect(p.start, day(2026, 9, 26));
      expect(p.end, day(2026, 10, 25));
      expect(p.days, 30);
    });

    test('暦月の days は月の日数と一致する', () {
      expect(BudgetPeriodService.periodFor(day(2026, 6, 15)).days, 30);
      expect(BudgetPeriodService.periodFor(day(2026, 1, 15)).days, 31);
      expect(BudgetPeriodService.periodFor(day(2026, 2, 15)).days, 28);
      expect(BudgetPeriodService.periodFor(day(2024, 2, 15)).days, 29);
    });

    test('締め日25の期間ラベル', () {
      final p =
          BudgetPeriodService.periodFor(day(2026, 10, 25), closingDay: 25);
      expect(p.label, '2026/09/26 〜 2026/10/25');
    });

    test('暦月の期間ラベルはゼロ埋めされる', () {
      final p = BudgetPeriodService.periodFor(day(2026, 6, 15));
      expect(p.label, '2026/06/01 〜 2026/06/30');
    });

    test('同じ期間は == かつ hashCode が一致し、違えば不一致', () {
      final a = BudgetPeriodService.periodFor(day(2026, 11, 1), closingDay: 25);
      final b =
          BudgetPeriodService.periodFor(day(2026, 11, 25), closingDay: 25);
      final c =
          BudgetPeriodService.periodFor(day(2026, 11, 26), closingDay: 25);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    test('toString は締め日と期間を含む', () {
      final p =
          BudgetPeriodService.periodFor(day(2026, 10, 25), closingDay: 25);
      expect(p.toString(), contains('25'));
      expect(p.toString(), contains('2026-09-26'));
      expect(p.toString(), contains('2026-10-25'));
    });
  });

  group('BudgetPeriod.previous / next', () {
    test('暦月の previous は前月（12月→翌年1月の逆方向）', () {
      final p = BudgetPeriodService.periodFor(day(2026, 1, 10));
      final prev = p.previous;
      expect(prev.start, day(2025, 12, 1));
      expect(prev.end, day(2025, 12, 31));
      expect(prev.days, 31);
    });

    test('締め日25の next は 11/26〜12/25', () {
      final p = BudgetPeriodService.periodFor(day(2026, 11, 1), closingDay: 25);
      final next = p.next;
      expect(next.start, day(2026, 11, 26));
      expect(next.end, day(2026, 12, 25));
    });

    test('next.previous は元の期間に戻る（締め日 1/2/5/25/28）', () {
      for (final cd in [1, 2, 5, 25, 28]) {
        final p =
            BudgetPeriodService.periodFor(day(2026, 11, 15), closingDay: cd);
        expect(p.next.previous, equals(p), reason: 'closingDay=$cd');
        expect(p.previous.next, equals(p), reason: 'closingDay=$cd');
      }
    });

    test('2月締め(28日)を跨いでも往復する', () {
      final p = BudgetPeriodService.periodFor(day(2027, 3, 1), closingDay: 28);
      expect(p.end, day(2027, 3, 28));
      expect(p.previous.start, day(2027, 1, 29));
      expect(p.previous.end, day(2027, 2, 28));
      expect(p.previous.next, equals(p));
      expect(p.next.previous, equals(p));
    });

    test('月末日数の差で期間がずれない（31日月 → 30日月）', () {
      final p =
          BudgetPeriodService.periodFor(day(2026, 10, 15), closingDay: 25);
      expect(p.start, day(2026, 9, 26));
      expect(p.end, day(2026, 10, 25));
      expect(p.previous.start, day(2026, 8, 26));
      expect(p.previous.end, day(2026, 9, 25));
      expect(p.next.start, day(2026, 10, 26));
      expect(p.next.end, day(2026, 11, 25));
    });
  });

  group('BudgetPeriodService.normalize', () {
    test('0以下・上限超えは既定値1へ', () {
      expect(BudgetPeriodService.normalize(0), 1);
      expect(BudgetPeriodService.normalize(-3), 1);
      expect(BudgetPeriodService.normalize(29), 1);
      expect(BudgetPeriodService.normalize(100), 1);
    });

    test('1〜28はそのまま', () {
      expect(BudgetPeriodService.normalize(1), 1);
      expect(BudgetPeriodService.normalize(25), 25);
      expect(BudgetPeriodService.normalize(28), 28);
    });

    test('定数が公開されている', () {
      expect(BudgetPeriodService.defaultClosingDay, 1);
      expect(BudgetPeriodService.minClosingDay, 1);
      expect(BudgetPeriodService.maxClosingDay, 28);
    });
  });

  group('BudgetPeriodService のラベル文言', () {
    test('closingDayLabel(1) は毎月末日締め', () {
      expect(BudgetPeriodService.closingDayLabel(1), '毎月末日締め');
    });

    test('closingDayLabel(25) は毎月25日締め', () {
      expect(BudgetPeriodService.closingDayLabel(25), '毎月25日締め');
    });

    test('transitionLabel(1) は暦月', () {
      expect(BudgetPeriodService.transitionLabel(1), '暦月（1日〜末日）');
    });

    test('transitionLabel(25) は前月26日〜当月25日', () {
      expect(BudgetPeriodService.transitionLabel(25), '前月26日〜当月25日');
    });
  });
}
