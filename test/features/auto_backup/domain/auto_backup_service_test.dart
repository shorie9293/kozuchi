import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/features/auto_backup/data/auto_backup_store.dart';
import 'package:kozuchi/features/auto_backup/domain/auto_backup_policy.dart';
import 'package:kozuchi/features/auto_backup/domain/auto_backup_service.dart';

/// 壊れた在庫（例外を返す保管庫）を模す試練用フェイク。
class _ThrowingStore implements AutoBackupStore {
  @override
  Future<List<AutoBackupEntry>> list() async => throw StateError('list失敗');

  @override
  Future<void> write(String fileName, String contents) async =>
      throw StateError('write失敗');

  @override
  Future<void> delete(String fileName) async {}
}

/// 自動バックアップの実行手順（判定→採取→書込→世代整理）を検める試練。
void main() {
  late DateTime current;
  late InMemoryAutoBackupStore store;
  late AutoBackupService service;

  setUp(() {
    current = DateTime(2026, 10, 1, 9, 0);
    store = InMemoryAutoBackupStore(now: () => current);
    service = AutoBackupService(store: store, now: () => current);
  });

  Future<String> buildJson() async => '{"exportedAt":"x"}';

  test('前回が24時間以内ならスキップする（書き込まない）', () async {
    final first = await service.run(buildJson);
    expect(first.ran, isTrue);

    current = current.add(const Duration(hours: 5));
    final second = await service.run(buildJson);

    expect(second.ran, isFalse);
    expect(second.fileName, isNull);
    expect(second.error, isNull);
    expect(store.files.keys, ['auto_backup_20261001.json']);
  });

  test('初回は JSON を採取してファイルへ書き出す', () async {
    final result = await service.run(() async => '{"a":1}');

    expect(result.ran, isTrue);
    expect(result.error, isNull);
    expect(result.fileName, 'auto_backup_20261001.json');
    expect(result.pruned, isEmpty);
    expect(store.files['auto_backup_20261001.json'], '{"a":1}');
  });

  test('24時間経過後は新たな世代を書き出す', () async {
    await service.run(buildJson);
    current = current.add(const Duration(hours: 24));

    final result = await service.run(buildJson);

    expect(result.ran, isTrue);
    expect(result.fileName, 'auto_backup_20261002.json');
    expect(store.files.length, 2);
  });

  test('4件目を書くと最古の1件を削除して3世代に保つ', () async {
    for (var i = 0; i < 4; i++) {
      await service.run(buildJson);
      current = current.add(const Duration(days: 1));
    }

    expect(store.files.length, 3);
    expect(store.files.containsKey('auto_backup_20261001.json'), isFalse);
    expect(store.files.containsKey('auto_backup_20261004.json'), isTrue);
  });

  test('prune は削除したファイル名を返す', () async {
    await service.run(buildJson);
    current = current.add(const Duration(days: 1));
    await service.run(buildJson);
    current = current.add(const Duration(days: 1));
    await service.run(buildJson);
    current = current.add(const Duration(days: 1));
    final result = await service.run(buildJson);

    expect(result.pruned, ['auto_backup_20261001.json']);
  });

  test('採取が例外を投げても握りつぶして error を返す', () async {
    final result = await service.run(() async => throw StateError('採取失敗'));

    expect(result.ran, isFalse);
    expect(result.error, isNotNull);
    expect(result.error, contains('採取失敗'));
    expect(store.files, isEmpty);
  });

  test('保管庫の例外も握りつぶして error を返す', () async {
    final failing = AutoBackupService(
      store: _ThrowingStore(),
      now: () => current,
    );

    final result = await failing.run(buildJson);

    expect(result.ran, isFalse);
    expect(result.error, isNotNull);
  });

  test('同日に2回実行しても1件しか作らない（冪等）', () async {
    await service.run(buildJson);
    current = current.add(const Duration(hours: 1));
    final second = await service.run(() async => '{"a":2}');

    expect(second.ran, isFalse);
    expect(store.files.length, 1);
    expect(store.files['auto_backup_20261001.json'], '{"exportedAt":"x"}');
  });

  test('policy を差し替えると世代数を変更できる', () async {
    final keepOne = AutoBackupService(
      store: store,
      policy: const AutoBackupPolicy(keep: 1),
      now: () => current,
    );
    await keepOne.run(buildJson);
    current = current.add(const Duration(days: 1));
    await keepOne.run(buildJson);
    current = current.add(const Duration(days: 1));
    final result = await keepOne.run(buildJson);

    expect(result.pruned, ['auto_backup_20261002.json']);
    expect(store.files.keys, ['auto_backup_20261003.json']);
  });

  group('InMemoryAutoBackupStore', () {
    test('list / write / delete が機能し、同日上書きは冪等', () async {
      final s = InMemoryAutoBackupStore(now: () => current);
      expect(await s.list(), isEmpty);

      await s.write('auto_backup_20261001.json', 'v1');
      await s.write('auto_backup_20261001.json', 'v2');
      final entries = await s.list();

      expect(entries.length, 1);
      expect(entries.single.fileName, 'auto_backup_20261001.json');
      expect(entries.single.createdAt, current);

      await s.delete('auto_backup_20261001.json');
      expect(await s.list(), isEmpty);
      // 存在しないファイルの削除は例外にしない
      await s.delete('auto_backup_20261001.json');
    });
  });

  group('FileAutoBackupStore', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('kozuchi_auto_backup_');
    });

    tearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    FileAutoBackupStore build() =>
        FileAutoBackupStore(directoryResolver: () async => dir);

    test('書き出した自動ファイルのみを一覧し、日付を createdAt に採る', () async {
      final s = build();
      await s.write('auto_backup_20261001.json', '{"a":1}');
      await s.write('kozuchi_backup_20261001_0900.json', '{"manual":1}');

      final entries = await s.list();

      expect(entries.length, 1);
      expect(entries.single.fileName, 'auto_backup_20261001.json');
      expect(entries.single.createdAt, DateTime(2026, 10, 1));
      expect(
        File('${dir.path}/auto_backup_20261001.json').readAsStringSync(),
        '{"a":1}',
      );
    });

    test('存在しないディレクトリの一覧は空を返し、削除は冪等', () async {
      final missing = FileAutoBackupStore(
        directoryResolver: () async => Directory('${dir.path}/nested'),
      );
      expect(await missing.list(), isEmpty);

      final s = build();
      await s.write('auto_backup_20261001.json', 'v');
      await s.delete('auto_backup_20261001.json');
      await s.delete('auto_backup_20261001.json');
      expect(await s.list(), isEmpty);
    });
  });
}
