import 'dart:convert';

import 'package:kozuchi/features/calendar_export/domain/calendar_event.dart';

/// iCalendar (.ics) の純粋生成器。
///
/// 副作用を持たず、与えられた予定群から決定的に文字列を組み立てる。
/// 改行は CRLF のみ、長い行は UTF-8 で 75 オクテット以内に畳む。
class IcsWriter {
  const IcsWriter._();

  static const String prodId = '-//Takamagahara//Yaoyorozu OS//JA';

  /// 1 物理行の最大オクテット数（RFC 5545）。
  static const int maxOctets = 75;

  /// iCalendar のテキスト値を退避する。
  ///
  /// バックスラッシュを最初に退避し、その後に `;` `,` 改行を処理する。
  static String escapeText(String text) {
    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    return normalized
        .replaceAll(r'\', r'\\')
        .replaceAll(';', r'\;')
        .replaceAll(',', r'\,')
        .replaceAll('\n', r'\n');
  }

  /// 行を 75 オクテット以内に畳む（継続行は半角スペース始まり）。
  ///
  /// rune 単位で走査するためマルチバイト文字を分断しない。
  /// 継続行の先頭スペースも 75 オクテットに含める。
  static String foldLine(String line) {
    final buffer = StringBuffer();
    var current = '';
    var currentOctets = 0;
    for (final rune in line.runes) {
      final char = String.fromCharCode(rune);
      final octets = utf8.encode(char).length;
      if (currentOctets + octets > maxOctets) {
        buffer.write(current);
        buffer.write('\r\n');
        current = ' $char';
        currentOctets = 1 + octets;
      } else {
        current += char;
        currentOctets += octets;
      }
    }
    buffer.write(current);
    return buffer.toString();
  }

  /// 予定群を ICS 文字列へ変換する。
  ///
  /// 入力リストは破壊せず、日付昇順→UID 昇順に安定ソートして出力する。
  static String write(
    List<CalendarEvent> events, {
    String calendarName = '高天原',
    DateTime? generatedAt,
  }) {
    final stamp = _utcStamp(generatedAt ?? DateTime.now().toUtc());
    final sorted = [...events]..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        if (byDate != 0) return byDate;
        return a.uid.compareTo(b.uid);
      });

    final lines = <String>[
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:$prodId',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
      'X-WR-CALNAME:${escapeText(calendarName)}',
    ];

    for (final event in sorted) {
      lines
        ..add('BEGIN:VEVENT')
        ..add('UID:${escapeText(event.uid)}')
        ..add('DTSTAMP:$stamp')
        ..add('DTSTART;VALUE=DATE:${event.dateStamp}')
        ..add('SUMMARY:${escapeText(event.summary)}');
      final description = event.description;
      if (description != null) {
        lines.add('DESCRIPTION:${escapeText(description)}');
      }
      lines.add('END:VEVENT');
    }
    lines.add('END:VCALENDAR');

    final buffer = StringBuffer();
    for (final line in lines) {
      buffer.write(foldLine(line));
      buffer.write('\r\n');
    }
    return buffer.toString();
  }

  static String _utcStamp(DateTime utc) {
    final u = utc.toUtc();
    String two(int value) => value.toString().padLeft(2, '0');
    final y = u.year.toString().padLeft(4, '0');
    return '$y${two(u.month)}${two(u.day)}T${two(u.hour)}${two(u.minute)}${two(u.second)}Z';
  }
}
