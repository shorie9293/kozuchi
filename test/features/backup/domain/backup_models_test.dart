import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/features/backup/domain/backup_models.dart';

void main() {
  group('BackupBundle', () {
    test('既定の schemaVersion は kBackupSchemaVersion（1）', () {
      final bundle = BackupBundle(
        exportedAt: DateTime.utc(2026, 10, 7),
        entries: {'a': 'b'},
      );
      expect(bundle.schemaVersion, kBackupSchemaVersion);
      expect(kBackupSchemaVersion, 1);
    });

    test('schemaVersion が 1 未満なら ArgumentError', () {
      expect(
        () => BackupBundle(
          schemaVersion: 0,
          exportedAt: DateTime.utc(2026, 10, 7),
          entries: {},
        ),
        throwsArgumentError,
      );
    });

    test('entryCount / isEmpty が entries に連動する', () {
      final empty = BackupBundle(
        exportedAt: DateTime.utc(2026, 10, 7),
        entries: {},
      );
      expect(empty.entryCount, 0);
      expect(empty.isEmpty, isTrue);

      final filled = BackupBundle(
        exportedAt: DateTime.utc(2026, 10, 7),
        entries: {'a': 1, 'b': 'x'},
      );
      expect(filled.entryCount, 2);
      expect(filled.isEmpty, isFalse);
    });

    test('toJson / fromJson の往復が保たれる', () {
      final bundle = BackupBundle(
        exportedAt: DateTime.utc(2026, 10, 7, 19, 0),
        entries: {
          'kozuchi_goals': <String>['a', 'b'],
          'kozuchi_count': 3,
          'kozuchi_ratio': 1.5,
          'kozuchi_flag': true,
        },
      );
      final restored = BackupBundle.fromJson(bundle.toJson());
      expect(restored.schemaVersion, bundle.schemaVersion);
      expect(restored.exportedAt, bundle.exportedAt);
      expect(restored.entries, bundle.entries);
    });

    test('fromJson: schemaVersion 欠落・非int は FormatException', () {
      expect(
        () => BackupBundle.fromJson({
          'exportedAt': '2026-10-07T00:00:00Z',
          'entries': <String, dynamic>{},
        }),
        throwsFormatException,
      );
      expect(
        () => BackupBundle.fromJson({
          'schemaVersion': '1',
          'exportedAt': '2026-10-07T00:00:00Z',
          'entries': <String, dynamic>{},
        }),
        throwsFormatException,
      );
    });

    test('fromJson: exportedAt 欠落・不正文字列は FormatException', () {
      expect(
        () => BackupBundle.fromJson({
          'schemaVersion': 1,
          'entries': <String, dynamic>{},
        }),
        throwsFormatException,
      );
      expect(
        () => BackupBundle.fromJson({
          'schemaVersion': 1,
          'exportedAt': 'not-a-date',
          'entries': <String, dynamic>{},
        }),
        throwsFormatException,
      );
    });

    test('fromJson: entries 欠落・非Map は FormatException', () {
      expect(
        () => BackupBundle.fromJson({
          'schemaVersion': 1,
          'exportedAt': '2026-10-07T00:00:00Z',
        }),
        throwsFormatException,
      );
      expect(
        () => BackupBundle.fromJson({
          'schemaVersion': 1,
          'exportedAt': '2026-10-07T00:00:00Z',
          'entries': 'nope',
        }),
        throwsFormatException,
      );
    });

    test('fromJson: 許容外の型の値は FormatException', () {
      final badValues = <Object?>[
        null,
        <String, dynamic>{'nested': 'map'},
        <Object>[1, 'x'], // リストに非String混入
      ];
      for (final bad in badValues) {
        expect(
          () => BackupBundle.fromJson({
            'schemaVersion': 1,
            'exportedAt': '2026-10-07T00:00:00Z',
            'entries': <String, dynamic>{'kozuchi_x': bad},
          }),
          throwsFormatException,
          reason: 'bad value: $bad',
        );
      }
    });
  });

  group('RestoreResult', () {
    test('total は3項目の合計', () {
      const result = RestoreResult(created: 1, restored: 2, unchanged: 3);
      expect(result.total, 6);
    });

    test('label は件数を日本語整形する', () {
      const result = RestoreResult(created: 1, restored: 2, unchanged: 3);
      expect(result.label, '新規 1件 / 更新 2件 / 変更なし 3件');
    });
  });
}
