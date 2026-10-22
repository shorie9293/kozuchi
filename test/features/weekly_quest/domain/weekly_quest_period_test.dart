import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/weekly_quest/domain/weekly_quest_period.dart';

/// ローカル時刻の日付を組み立てるヘルパー（実装側と同じ流儀）。
DateTime day(int year, int month, int dayOfMonth) =>
    DateTime(year, month, dayOfMonth);

void main() {
  group('WeeklyQuestPeriod.of', () {
    test('水曜はその週の月曜 00:00 に正規化される', () {
      final period = WeeklyQuestPeriod.of(day(2026, 10, 21));
      expect(period.weekStart, day(2026, 10, 19));
      expect(period.weekStart.hour, 0);
      expect(period.weekStart.minute, 0);
      expect(period.weekStart.weekday, DateTime.monday);
    });

    test('月曜自身はそのまま', () {
      final period = WeeklyQuestPeriod.of(day(2026, 10, 19));
      expect(period.weekStart, day(2026, 10, 19));
    });

    test('日曜は前の月曜に属する', () {
      final period = WeeklyQuestPeriod.of(day(2026, 10, 25));
      expect(period.weekStart, day(2026, 10, 19));
    });

    test('時刻が深夜でも日付だけで判定する', () {
      final before = WeeklyQuestPeriod.of(DateTime(2026, 10, 19, 0, 0, 1));
      final late = WeeklyQuestPeriod.of(DateTime(2026, 10, 25, 23, 59, 59));
      expect(before.weekStart, day(2026, 10, 19));
      expect(late.weekStart, day(2026, 10, 19));
    });

    test('年またぎ（1/1 が木曜）は前年12/29の月曜になる', () {
      final period = WeeklyQuestPeriod.of(day(2026, 1, 1));
      expect(period.weekStart, day(2025, 12, 29));
      expect(period.weekStart.weekday, DateTime.monday);
      expect(period.weekKey, '2025-12-29');
    });
  });

  group('weekEndExclusive / weekKey / label', () {
    final period = WeeklyQuestPeriod(weekStart: day(2026, 10, 19));

    test('weekEndExclusive は翌週月曜 00:00', () {
      expect(period.weekEndExclusive, day(2026, 10, 26));
    });

    test('weekKey はゼロ埋め日付', () {
      expect(period.weekKey, '2026-10-19');
      expect(
        WeeklyQuestPeriod(weekStart: day(2026, 1, 5)).weekKey,
        '2026-01-05',
      );
    });

    test('label は月〜日の曜日付き', () {
      expect(period.label, '10/19(月)〜10/25(日)');
    });

    test('label は年またぎでも日付のみ', () {
      final p = WeeklyQuestPeriod(weekStart: day(2025, 12, 29));
      expect(p.label, '12/29(月)〜1/4(日)');
    });
  });

  group('contains / hasEnded / remainingDays / isSameWeek', () {
    final period = WeeklyQuestPeriod(weekStart: day(2026, 10, 19));

    test('contains は開始以上・終端未満', () {
      expect(period.contains(day(2026, 10, 19)), isTrue);
      expect(period.contains(DateTime(2026, 10, 19, 0, 0, 0)), isTrue);
      expect(period.contains(DateTime(2026, 10, 25, 23, 59, 59)), isTrue);
      expect(period.contains(day(2026, 10, 26)), isFalse);
      expect(period.contains(day(2026, 10, 18)), isFalse);
    });

    test('hasEnded は終端以降で true', () {
      expect(period.hasEnded(day(2026, 10, 25)), isFalse);
      expect(period.hasEnded(DateTime(2026, 10, 25, 23, 59)), isFalse);
      expect(period.hasEnded(day(2026, 10, 26)), isTrue);
      expect(period.hasEnded(day(2026, 11, 2)), isTrue);
    });

    test('remainingDays は月曜7・週末1・終了後0', () {
      expect(period.remainingDays(day(2026, 10, 19)), 7);
      expect(period.remainingDays(day(2026, 10, 21)), 5);
      expect(period.remainingDays(day(2026, 10, 25)), 1);
      expect(period.remainingDays(day(2026, 10, 26)), 0);
      expect(period.remainingDays(day(2026, 11, 30)), 0);
    });

    test('remainingDays は週開始前なら7', () {
      expect(period.remainingDays(day(2026, 10, 18)), 7);
      expect(period.remainingDays(day(2026, 10, 1)), 7);
    });

    test('isSameWeek は同一週のみ true', () {
      expect(period.isSameWeek(day(2026, 10, 19)), isTrue);
      expect(period.isSameWeek(day(2026, 10, 25)), isTrue);
      expect(period.isSameWeek(day(2026, 10, 26)), isFalse);
      expect(period.isSameWeek(day(2026, 10, 18)), isFalse);
    });
  });

  group('等価性', () {
    test('同じ weekStart なら等しい', () {
      final a = WeeklyQuestPeriod(weekStart: day(2026, 10, 19));
      final b = WeeklyQuestPeriod.of(day(2026, 10, 22));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('週が違えば等しくない', () {
      final a = WeeklyQuestPeriod(weekStart: day(2026, 10, 19));
      final b = WeeklyQuestPeriod(weekStart: day(2026, 10, 26));
      expect(a == b, isFalse);
    });
  });
}
