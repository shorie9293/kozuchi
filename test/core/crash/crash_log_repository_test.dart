import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/core/crash/crash_log_entry.dart';
import 'package:kozuchi/core/crash/crash_log_repository.dart';

CrashLogEntry _entry(int i) => CrashLogEntry(
      timestamp: DateTime.utc(2026, 11, 1, 0, 0).add(Duration(minutes: i)),
      kind: CrashKind.flutterError,
      message: 'error-$i',
      stackTop: '#0 main (package:kozuchi/main.dart:1:1)',
    );

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kozuchi_crash_log_');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  FileCrashLogRepository buildRepository() =>
      FileCrashLogRepository(directoryProvider: () async => tempDir);

  group('FileCrashLogRepository', () {
    test('append するたびに 1行増える', () async {
      final repo = buildRepository();
      await repo.append(_entry(1));
      await repo.append(_entry(2));

      final file = File('${tempDir.path}/crash_log.jsonl');
      expect(await file.exists(), isTrue);
      final lines = (await file.readAsString())
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();
      expect(lines.length, 2);

      final loaded = await repo.loadAll();
      expect(loaded.length, 2);
      expect(loaded.first, _entry(1));
      expect(loaded.last, _entry(2));
    });

    test('51件目を追記すると最古が落ちて50件になる', () async {
      final repo = buildRepository();
      for (var i = 0; i < 51; i++) {
        await repo.append(_entry(i));
      }

      final loaded = await repo.loadAll();
      expect(loaded.length, FileCrashLogRepository.maxEntries);
      expect(loaded.length, 50);
      expect(loaded.first.message, 'error-1');
      expect(loaded.last.message, 'error-50');
      expect(
        loaded.map((e) => e.message).contains('error-0'),
        isFalse,
        reason: '最古の記録はローテートで落ちる',
      );
    });

    test('壊れた行は読み飛ばして健全な行だけ返す', () async {
      final repo = buildRepository();
      await repo.append(_entry(1));
      final file = File('${tempDir.path}/crash_log.jsonl');
      await file.writeAsString(
        'this is not json\n{"ts":"???"}\n',
        mode: FileMode.append,
      );
      await repo.append(_entry(2));

      final loaded = await repo.loadAll();
      expect(loaded.length, 2);
      expect(loaded.map((e) => e.message),
          containsAll(<String>['error-1', 'error-2']));
    });

    test('ファイルが無ければ空リスト、clear で空になる', () async {
      final repo = buildRepository();
      expect(await repo.loadAll(), isEmpty);

      await repo.append(_entry(1));
      await repo.clear();
      expect(await repo.loadAll(), isEmpty);
    });

    test('ディレクトリが作れない場合でも例外を投げない', () async {
      final repo = FileCrashLogRepository(
        directoryProvider: () async => Directory('/proc/kozuchi-impossible'),
      );
      // 書込失敗は握られ、例外にならないこと。
      await expectLater(repo.append(_entry(1)), completes);
    });
  });

  group('InMemoryCrashLogRepository', () {
    test('追記・全件・ローテート・clear が同じ契約で動く', () async {
      final repo = InMemoryCrashLogRepository();
      for (var i = 0; i < 51; i++) {
        await repo.append(_entry(i));
      }
      final loaded = await repo.loadAll();
      expect(loaded.length, 50);
      expect(loaded.first.message, 'error-1');

      await repo.clear();
      expect(await repo.loadAll(), isEmpty);
    });
  });
}
