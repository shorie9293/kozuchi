import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/features/auto_backup/data/auto_backup_restorer_impl.dart';
import 'package:kozuchi/features/auto_backup/data/auto_backup_store.dart';
import 'package:kozuchi/features/auto_backup/domain/auto_backup_policy.dart';

/// 操作の発生順を記録する試練用フェイク保管庫。
class _RecordingStore implements AutoBackupStore {
  final List<String> events = <String>[];
  final Map<String, String> files = <String, String>{};

  @override
  Future<List<AutoBackupEntry>> list() async => files.keys
      .map((name) => AutoBackupEntry(
            fileName: name,
            createdAt: DateTime(2026, 10, 1),
          ))
      .toList();

  @override
  Future<String?> read(String fileName) async {
    events.add('read:$fileName');
    return files[fileName];
  }

  @override
  Future<void> write(String fileName, String contents) async {
    events.add('write:$fileName');
    files[fileName] = contents;
  }

  @override
  Future<void> delete(String fileName) async {
    events.add('delete:$fileName');
    files.remove(fileName);
  }
}

/// 自動バックアップからの復元手順を検める試練。
void main() {
  late DateTime current;
  late _RecordingStore store;
  late List<String> appliedJson;

  setUp(() {
    current = DateTime(2026, 10, 29, 7, 12);
    store = _RecordingStore();
    store.files['auto_backup_20261028.json'] = '{"exportedAt":"old"}';
    appliedJson = <String>[];
  });

  AutoBackupRestorerImpl build() => AutoBackupRestorerImpl(
        store: store,
        now: () => current,
        buildCurrentJson: () async => '{"exportedAt":"now"}',
        applyBackup: (json) async => appliedJson.add(json),
      );

  test('復元前に本日分の現状を強制保存してから適用する（順序）', () async {
    final result = await build().restore('auto_backup_20261028.json');

    expect(result.ok, isTrue);
    expect(result.safetyFileName, 'auto_backup_20261029.json');
    expect(appliedJson, ['{"exportedAt":"old"}']);
    expect(store.files['auto_backup_20261029.json'], '{"exportedAt":"now"}');
    expect(
      store.events,
      [
        'read:auto_backup_20261028.json',
        'write:auto_backup_20261029.json',
      ],
    );
  });

  test('壊れたJSONは適用しない（安全保存も走らない）', () async {
    store.files['auto_backup_20261027.json'] = '{broken';

    final result = await build().restore('auto_backup_20261027.json');

    expect(result.ok, isFalse);
    expect(result.message, isNotNull);
    expect(appliedJson, isEmpty);
    expect(store.events, ['read:auto_backup_20261027.json']);
  });

  test('存在しないファイルは復元しない', () async {
    final result = await build().restore('auto_backup_20260101.json');

    expect(result.ok, isFalse);
    expect(appliedJson, isEmpty);
    expect(store.events, ['read:auto_backup_20260101.json']);
  });

  test('適用が例外を投げても投げ返さず ok:false を返す', () async {
    final failing = AutoBackupRestorerImpl(
      store: store,
      now: () => current,
      buildCurrentJson: () async => '{"exportedAt":"now"}',
      applyBackup: (json) async => throw StateError('適用失敗'),
    );

    final result = await failing.restore('auto_backup_20261028.json');

    expect(result.ok, isFalse);
    expect(result.message, contains('適用失敗'));
    // 安全保存は適用前に済んでいる
    expect(store.files['auto_backup_20261029.json'], '{"exportedAt":"now"}');
  });

  test('現状採取が例外を投げても投げ返さず ok:false を返す', () async {
    final failing = AutoBackupRestorerImpl(
      store: store,
      now: () => current,
      buildCurrentJson: () async => throw StateError('採取失敗'),
      applyBackup: (json) async => appliedJson.add(json),
    );

    final result = await failing.restore('auto_backup_20261028.json');

    expect(result.ok, isFalse);
    expect(result.message, contains('採取失敗'));
    expect(appliedJson, isEmpty);
  });

  test('復元先が本日分でも読み出した内容で適用する', () async {
    store.files['auto_backup_20261029.json'] = '{"exportedAt":"today-old"}';

    final result = await build().restore('auto_backup_20261029.json');

    expect(result.ok, isTrue);
    expect(appliedJson, ['{"exportedAt":"today-old"}']);
  });

  test('policy の保持数は復元結果に影響しない（世代名は now 基準）', () async {
    final result = await AutoBackupRestorerImpl(
      store: store,
      policy: const AutoBackupPolicy(keep: 5),
      now: () => current,
      buildCurrentJson: () async => '{"exportedAt":"now"}',
      applyBackup: (json) async => appliedJson.add(json),
    ).restore('auto_backup_20261028.json');

    expect(result.safetyFileName, AutoBackupPolicy.fileNameFor(current));
  });
}
