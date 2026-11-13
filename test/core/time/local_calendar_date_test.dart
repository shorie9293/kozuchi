import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/core/time/local_calendar_date.dart';

/// ローカル暦の正準化関数群の試練。
///
/// 契約: 保存形式（Z 付き / Z 無し）に依らず、**必ず端末のローカル暦**の
/// 年・月・日を返す。壊れた入力では throw しない（null を返す）。
void main() {
  group('localCalendarDate', () {
    test('UTC の瞬間をローカル暦の日付へ正規化する（JST 早朝の前日ズレを防ぐ）', () {
      // JST 2026-11-13 08:30 = UTC 2026-11-12T23:30Z
      final instant = DateTime.parse('2026-11-12T23:30:00.000Z');
      final local = instant.toLocal();
      final day = localCalendarDate(instant);
      expect(day.year, local.year);
      expect(day.month, local.month);
      expect(day.day, local.day);
      expect(day.hour, 0);
      expect(day.minute, 0);
      expect(day.isUtc, isFalse);
    });

    test('月初の瞬間でもローカル暦の月を取り違えない', () {
      // JST 2026-11-01 00:05 = UTC 2026-10-31T15:05Z
      final instant = DateTime.parse('2026-10-31T15:05:00.000Z');
      final local = instant.toLocal();
      final day = localCalendarDate(instant);
      expect(day.month, local.month);
      expect(day.day, local.day);
    });

    test('ローカルの DateTime に対しては冪等（既存データの意味を変えない）', () {
      final local = DateTime(2026, 6, 22, 14, 30);
      final day = localCalendarDate(local);
      expect(day, DateTime(2026, 6, 22));
      expect(localCalendarDate(day), day);
    });

    test('時分秒を切り捨てる（同日判定に使える）', () {
      final a = DateTime(2026, 11, 13, 0, 0, 1);
      final b = DateTime(2026, 11, 13, 23, 59, 59);
      expect(localCalendarDate(a), localCalendarDate(b));
    });
  });

  group('tryParseStoredDateTime', () {
    test('Z 付き文字列をローカル瞬間として返す', () {
      final parsed = tryParseStoredDateTime('2026-11-12T23:30:00.000Z');
      expect(parsed, isNotNull);
      expect(parsed!.isUtc, isFalse);
      expect(parsed.isAtSameMomentAs(DateTime.parse('2026-11-12T23:30:00.000Z')),
          isTrue);
    });

    test('Z 無し（既存ローカル保存）はそのままの壁時計を保つ', () {
      final parsed = tryParseStoredDateTime('2026-06-22T14:30:00.000');
      expect(parsed, DateTime(2026, 6, 22, 14, 30));
      expect(parsed!.isUtc, isFalse);
    });

    test('壊れた入力で throw しない（null を返す）', () {
      expect(tryParseStoredDateTime(null), isNull);
      expect(tryParseStoredDateTime(''), isNull);
      expect(tryParseStoredDateTime('not-a-date'), isNull);
      expect(tryParseStoredDateTime(12345), isNull);
      expect(tryParseStoredDateTime({'date': '2026-01-01'}), isNull);
    });
  });

  group('isSameLocalCalendarDay / キー生成', () {
    test('UTC の瞬間とローカルの同日を一致と判定する', () {
      final utc = DateTime.parse('2026-11-12T23:30:00.000Z'); // JST 11/13 08:30
      final local = utc.toLocal();
      expect(isSameLocalCalendarDay(utc, local), isTrue);
      expect(
        isSameLocalCalendarDay(utc, DateTime(local.year, local.month, local.day, 23, 59)),
        isTrue,
      );
    });

    test('前日は不一致', () {
      final utc = DateTime.parse('2026-11-12T23:30:00.000Z');
      final local = utc.toLocal();
      final previous = DateTime(local.year, local.month, local.day)
          .subtract(const Duration(days: 1));
      expect(isSameLocalCalendarDay(utc, previous), isFalse);
    });

    test('月キーはローカル暦で作られる', () {
      final utc = DateTime.parse('2026-10-31T15:05:00.000Z'); // JST 11/01 00:05
      final local = utc.toLocal();
      expect(localMonthKey(utc), '${local.year}-${local.month.toString().padLeft(2, '0')}');
      expect(localDateKey(utc),
          '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}');
    });
  });
}
