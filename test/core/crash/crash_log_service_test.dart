import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/core/crash/crash_log_entry.dart';
import 'package:kozuchi/core/crash/crash_log_repository.dart';
import 'package:kozuchi/core/crash/crash_log_service.dart';

CrashLogEntry _entry(DateTime ts, String message) => CrashLogEntry(
      timestamp: ts,
      kind: CrashKind.zoneError,
      message: message,
      stackTop: '',
    );

void main() {
  group('CrashLogger', () {
    test('record で 1行増える（kind とメッセージが残る）', () async {
      final repo = InMemoryCrashLogRepository();
      final logger = CrashLogger(repo);

      await logger.record(
        StateError('壊れた'),
        StackTrace.current,
        kind: CrashKind.flutterError,
      );

      final entries = await repo.loadAll();
      expect(entries.length, 1);
      expect(entries.single.kind, CrashKind.flutterError);
      expect(entries.single.message, contains('壊れた'));
    });

    test('記録先が失敗しても record は例外を投げない', () async {
      final logger = CrashLogger(_ThrowingRepository());
      await expectLater(
        logger.record(StateError('x'), null),
        completes,
      );
    });
  });

  group('summarize', () {
    final now = DateTime.utc(2026, 11, 1, 12, 0);

    test('0件なら null', () {
      expect(summarize(const <CrashLogEntry>[], now: now), isNull);
    });

    test('2件なら「前回の異常終了 2件（最終 HH:mm）」', () {
      final entries = [
        _entry(DateTime.utc(2026, 11, 1, 9, 5), 'a'),
        _entry(DateTime.utc(2026, 11, 1, 9, 31), 'b'),
      ];
      expect(summarize(entries, now: now), '前回の異常終了 2件（最終 09:31）');
    });

    test('最終時刻は並び順に依存せず最新を採る', () {
      final entries = [
        _entry(DateTime.utc(2026, 11, 1, 23, 59), 'later'),
        _entry(DateTime.utc(2026, 11, 1, 1, 2), 'earlier'),
      ];
      expect(summarize(entries, now: now), '前回の異常終了 2件（最終 23:59）');
    });
  });

  group('recent', () {
    test('新しい順に limit 件だけ返す', () {
      final entries = [
        _entry(DateTime.utc(2026, 11, 1, 1), 'old'),
        _entry(DateTime.utc(2026, 11, 1, 3), 'new'),
        _entry(DateTime.utc(2026, 11, 1, 2), 'mid'),
      ];
      final result = recent(entries, limit: 2);
      expect(result.map((e) => e.message).toList(), <String>['new', 'mid']);
    });

    test('limit が件数より大きくても壊れない', () {
      final entries = [_entry(DateTime.utc(2026, 11, 1, 1), 'only')];
      expect(recent(entries, limit: 10).length, 1);
      expect(recent(entries, limit: 0), isEmpty);
    });
  });
}

class _ThrowingRepository implements CrashLogRepository {
  @override
  Future<void> append(CrashLogEntry entry) async => throw StateError('disk');

  @override
  Future<void> clear() async => throw StateError('disk');

  @override
  Future<List<CrashLogEntry>> loadAll() async => throw StateError('disk');
}
