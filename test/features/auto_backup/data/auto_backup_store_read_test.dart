import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/features/auto_backup/data/auto_backup_store.dart';

/// 保管庫の読み出し（read）を検める試練。
void main() {
  group('InMemoryAutoBackupStore.read', () {
    test('write した内容を読み出せる（往復）', () async {
      final store = InMemoryAutoBackupStore(
        now: () => DateTime(2026, 10, 29, 7, 12),
      );

      await store.write('auto_backup_20261029.json', '{"a":1}');

      expect(await store.read('auto_backup_20261029.json'), '{"a":1}');
    });

    test('未存在のファイルは null', () async {
      final store = InMemoryAutoBackupStore();

      expect(await store.read('auto_backup_20260101.json'), isNull);
    });

    test('削除後は null', () async {
      final store = InMemoryAutoBackupStore();
      await store.write('auto_backup_20261029.json', 'v');
      await store.delete('auto_backup_20261029.json');

      expect(await store.read('auto_backup_20261029.json'), isNull);
    });
  });

  group('FileAutoBackupStore.read', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('kozuchi_auto_backup_read_');
    });

    tearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    FileAutoBackupStore build() =>
        FileAutoBackupStore(directoryResolver: () async => dir);

    test('write した内容を UTF8 文字列として読み出せる（往復）', () async {
      final store = build();
      await store.write('auto_backup_20261029.json', '{"a":"日記"}');

      expect(await store.read('auto_backup_20261029.json'), '{"a":"日記"}');
    });

    test('未存在のファイルは null（例外にしない）', () async {
      expect(await build().read('auto_backup_20260101.json'), isNull);
    });

    test('ディレクトリ自体が無くても null', () async {
      final missing = FileAutoBackupStore(
        directoryResolver: () async => Directory('${dir.path}/nested'),
      );

      expect(await missing.read('auto_backup_20260101.json'), isNull);
    });
  });
}
