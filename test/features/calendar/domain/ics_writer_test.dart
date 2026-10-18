import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/calendar_export/domain/calendar_event.dart';
import 'package:kozuchi/features/calendar_export/domain/ics_writer.dart';

/// 物理行に畳まれた ICS を元の論理行へ戻す。
String _unfold(String ics) {
  final buffer = <String>[];
  for (final line in ics.split('\r\n')) {
    if (line.startsWith(' ') && buffer.isNotEmpty) {
      buffer[buffer.length - 1] = buffer[buffer.length - 1] + line.substring(1);
    } else if (line.isNotEmpty) {
      buffer.add(line);
    }
  }
  return buffer.join('\n');
}

void main() {
  group('escapeText', () {
    test('バックスラッシュ・セミコロン・カンマを退避する', () {
      expect(IcsWriter.escapeText(r'a\b;c,d'), r'a\\b\;c\,d');
    });

    test('改行は \\n へ変換する', () {
      expect(IcsWriter.escapeText('1行目\n2行目'), r'1行目\n2行目');
      expect(IcsWriter.escapeText('1行目\r\n2行目'), r'1行目\n2行目');
    });

    test('バックスラッシュを最初に退避し二重退避しない', () {
      expect(IcsWriter.escapeText(r'\n'), r'\\n');
    });
  });

  group('foldLine', () {
    test('ASCII 75 オクテット以内は畳まない', () {
      final line = 'SUMMARY:${'a' * 60}';
      expect(IcsWriter.foldLine(line), line);
    });

    test('長い行は 75 オクテット以下に畳まれ、継続行は半角スペース始まり', () {
      final line = 'SUMMARY:${'あ' * 40}';
      final folded = IcsWriter.foldLine(line);
      final physical = folded.split('\r\n');
      expect(physical.length, greaterThan(1));
      for (final part in physical) {
        expect(utf8.encode(part).length, lessThanOrEqualTo(75));
      }
      for (final part in physical.skip(1)) {
        expect(part.startsWith(' '), isTrue);
      }
    });

    test('マルチバイト文字を分断しない（畳み戻すと元に戻る）', () {
      final line = 'DESCRIPTION:${'高天原の支払い' * 12}';
      final folded = IcsWriter.foldLine(line);
      expect(_unfold('$folded\r\n'), line);
    });
  });

  group('write', () {
    final events = [
      CalendarEvent(
        uid: 'koz-recurring-b-20260203@takamagahara',
        date: DateTime(2026, 2, 3),
        summary: '『家賃 ¥80000』',
        description: '種別: 定期取引 / カテゴリ: 住居',
      ),
      CalendarEvent(
        uid: 'koz-recurring-a-20260105@takamagahara',
        date: DateTime(2026, 1, 5),
        summary: '『電気代 ¥6000』',
      ),
    ];

    test('CRLF のみで改行し、VCALENDAR の骨格を持つ', () {
      final ics = IcsWriter.write(
        events,
        calendarName: '高天原の支払い',
        generatedAt: DateTime.utc(2026, 1, 1, 0, 0, 0),
      );

      expect(ics.startsWith('BEGIN:VCALENDAR\r\n'), isTrue);
      expect(ics.endsWith('END:VCALENDAR\r\n'), isTrue);
      // 裸の LF が無いこと（CRLF 以外の改行禁止）
      expect(ics.replaceAll('\r\n', '').contains('\n'), isFalse);
      expect(ics, contains('VERSION:2.0'));
      expect(ics, contains('PRODID:${IcsWriter.prodId}'));
      expect(ics, contains('CALSCALE:GREGORIAN'));
      expect(ics, contains('METHOD:PUBLISH'));
      expect(ics, contains('X-WR-CALNAME:高天原の支払い'));
      expect(ics, contains('DTSTAMP:20260101T000000Z'));
    });

    test('VEVENT を日付昇順→uid 昇順で安定ソートする', () {
      final ics = IcsWriter.write(
        events,
        generatedAt: DateTime.utc(2026, 1, 1),
      );

      final jan = ics.indexOf('UID:koz-recurring-a-20260105@takamagahara');
      final feb = ics.indexOf('UID:koz-recurring-b-20260203@takamagahara');
      expect(jan, greaterThanOrEqualTo(0));
      expect(feb, greaterThan(jan));
      expect(ics, contains('DTSTART;VALUE=DATE:20260105'));
      expect(ics, contains('DTSTART;VALUE=DATE:20260203'));
      expect(ics, contains('SUMMARY:『電気代 ¥6000』'));
      expect(ics, contains('DESCRIPTION:種別: 定期取引 / カテゴリ: 住居'));
    });

    test('入力を破壊しない（元リストの順序が保たれる）', () {
      final input = [...events];
      IcsWriter.write(input, generatedAt: DateTime.utc(2026, 1, 1));
      expect(input.first.uid, 'koz-recurring-b-20260203@takamagahara');
      expect(input.length, 2);
    });

    test('description が null なら DESCRIPTION 行を出さない', () {
      final ics = IcsWriter.write(
        [events.last],
        generatedAt: DateTime.utc(2026, 1, 1),
      );
      expect(ics, isNot(contains('DESCRIPTION:')));
      expect(ics, contains('BEGIN:VEVENT'));
      expect(ics, contains('END:VEVENT'));
    });
  });

  group('CalendarEvent.dateStamp', () {
    test('YYYYMMDD 形式', () {
      final event = CalendarEvent(
        uid: 'u',
        date: DateTime(2026, 3, 7),
        summary: 's',
      );
      expect(event.dateStamp, '20260307');
    });
  });
}
