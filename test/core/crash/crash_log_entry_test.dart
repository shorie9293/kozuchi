import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/core/crash/crash_log_entry.dart';

void main() {
  group('CrashLogEntry', () {
    test('toJson/fromJson で往復でき、値等価が成り立つ', () {
      final entry = CrashLogEntry(
        timestamp: DateTime.utc(2026, 11, 1, 9, 31, 5),
        kind: CrashKind.flutterError,
        message: 'boom',
        stackTop: '#0 main (package:kozuchi/main.dart:1:1)',
      );

      final restored = CrashLogEntry.fromJson(entry.toJson());

      expect(restored, isNotNull);
      expect(restored, entry);
      expect(restored!.hashCode, entry.hashCode);
      expect(restored.kind, CrashKind.flutterError);
    });

    test('壊れた JSON は null を返す（行ごと読み飛ばせる）', () {
      expect(CrashLogEntry.tryDecodeLine('{ broken'), isNull);
      expect(CrashLogEntry.tryDecodeLine('null'), isNull);
      expect(CrashLogEntry.tryDecodeLine('{"ts":"not-a-date"}'), isNull);
      expect(
        CrashLogEntry.tryDecodeLine(jsonEncode({'kind': 'zone'})),
        isNull,
        reason: 'ts が無いものは壊れた行として扱う',
      );
    });

    test('message は先頭200文字、stack は先頭10フレームに切り詰める', () {
      final longMessage = 'あ' * 500;
      final rawStack = List.generate(
        30,
        (i) => '#$i main (package:kozuchi/main.dart:$i:1)',
      ).join('\n');

      final entry = CrashLogEntry.fromError(
        longMessage,
        StackTrace.fromString(rawStack),
        kind: CrashKind.zoneError,
      );

      expect(entry.message.length, CrashLogEntry.maxMessageChars);
      expect(entry.message, 'あ' * 200);
      expect(entry.stackTop.split('\n').length, CrashLogEntry.maxStackFrames);
      expect(entry.stackTop.contains('#9 '), isTrue);
      expect(entry.stackTop.contains('#10 '), isFalse);
    });

    test('短いメッセージ・スタックはそのまま保持し、null スタックは空文字', () {
      final entry = CrashLogEntry.fromError(
        StateError('短い'),
        null,
        kind: CrashKind.platformError,
      );
      expect(entry.message, contains('短い'));
      expect(entry.stackTop, '');
      expect(entry.kind, CrashKind.platformError);
    });

    test('未知の kind は zoneError として復元する（前方互換）', () {
      final restored = CrashLogEntry.fromJson(<String, dynamic>{
        'ts': DateTime.utc(2026, 11, 1).toIso8601String(),
        'kind': 'unknown-future-kind',
        'message': 'x',
        'stack': '',
      });
      expect(restored?.kind, CrashKind.zoneError);
    });

    test('timeLabel は HH:mm', () {
      final entry = CrashLogEntry(
        timestamp: DateTime(2026, 11, 1, 7, 5),
        kind: CrashKind.zoneError,
        message: 'x',
        stackTop: '',
      );
      expect(entry.timeLabel, '07:05');
    });
  });
}
