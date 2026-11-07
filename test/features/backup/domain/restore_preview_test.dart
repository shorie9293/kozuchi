import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/features/backup/domain/backup_models.dart';
import 'package:kozuchi/features/backup/domain/backup_service.dart';
import 'package:kozuchi/features/backup/domain/restore_preview.dart';

void main() {
  RestoreDiff diffOf({
    Map<String, Object?> create = const {},
    Map<String, Object?> overwrite = const {},
    int unchanged = 0,
  }) {
    return RestoreDiff(
      toCreate: create,
      toOverwrite: overwrite,
      unchanged: unchanged,
    );
  }

  group('RestorePreview.build の内訳', () {
    test('新規のみなら上書きされない旨を出し、サンプルは無い', () {
      final preview = RestorePreview.build(
        diffOf(create: {
          'a': 1,
          'b': 2,
          'c': 3,
        }),
      );

      expect(preview.created, 3);
      expect(preview.overwritten, 0);
      expect(preview.unchanged, 0);
      expect(preview.summary, '新規 3件 / 上書き 0件 / 変更なし 0件');
      expect(preview.message, contains('既存データは上書きされません'));
      expect(preview.overwriteSampleKeys, isEmpty);
      expect(preview.hiddenOverwriteCount, 0);
      expect(preview.samplesText, isNull);
    });

    test('上書きのみなら上書きされる旨とサンプルを出す', () {
      final preview = RestorePreview.build(
        diffOf(overwrite: {'kozuchi_a': 'x', 'kozuchi_b': 'y'}),
      );

      expect(preview.created, 0);
      expect(preview.overwritten, 2);
      expect(preview.summary, '新規 0件 / 上書き 2件 / 変更なし 0件');
      expect(preview.message, contains('既存データが上書きされます'));
      expect(preview.overwriteSampleKeys, ['kozuchi_a', 'kozuchi_b']);
      expect(preview.samplesText, isNotNull);
      expect(preview.samplesText, contains('kozuchi_a'));
      expect(preview.samplesText, contains('kozuchi_b'));
      expect(preview.samplesText, isNot(contains('ほか')));
    });

    test('全件 unchanged なら「変更はありません」と言い切る', () {
      final preview = RestorePreview.build(diffOf(unchanged: 7));

      expect(preview.created, 0);
      expect(preview.overwritten, 0);
      expect(preview.unchanged, 7);
      expect(preview.summary, '新規 0件 / 上書き 0件 / 変更なし 7件');
      expect(preview.message, contains('変更はありません'));
      expect(preview.samplesText, isNull);
    });

    test('混在時は内訳と上書きキーの先頭5件＋ほか N件 を出す', () {
      final overwrite = <String, Object?>{
        for (var i = 1; i <= 8; i++) 'kozuchi_k$i': i,
      };
      final preview = RestorePreview.build(
        diffOf(create: {'kozuchi_new': 1}, overwrite: overwrite, unchanged: 2),
      );

      expect(preview.created, 1);
      expect(preview.overwritten, 8);
      expect(preview.unchanged, 2);
      expect(preview.summary, '新規 1件 / 上書き 8件 / 変更なし 2件');
      expect(preview.overwriteSampleKeys.length, 5);
      expect(preview.hiddenOverwriteCount, 3);
      expect(preview.samplesText, contains('kozuchi_k1'));
      expect(preview.samplesText, contains('kozuchi_k5'));
      expect(preview.samplesText, isNot(contains('kozuchi_k6')));
      expect(preview.samplesText, contains('ほか 3件'));
    });
  });

  group('RestorePreview.build の境界', () {
    test('空 diff は「復元対象のデータはありません」', () {
      final preview = RestorePreview.build(diffOf());

      expect(preview.summary, '新規 0件 / 上書き 0件 / 変更なし 0件');
      expect(preview.message, contains('復元対象のデータはありません'));
      expect(preview.samplesText, isNull);
    });

    test('sampleLimit を超えた上書きは hiddenOverwriteCount に計上する', () {
      final overwrite = <String, Object?>{
        for (var i = 1; i <= 9; i++) 'k$i': i,
      };
      final preview =
          RestorePreview.build(diffOf(overwrite: overwrite), sampleLimit: 3);

      expect(preview.overwriteSampleKeys, ['k1', 'k2', 'k3']);
      expect(preview.hiddenOverwriteCount, 6);
      expect(preview.samplesText, contains('ほか 6件'));
    });

    test('sampleLimit が上書き件数以上なら hidden は 0', () {
      final preview = RestorePreview.build(
        diffOf(overwrite: {'k1': 1, 'k2': 2}),
        sampleLimit: 5,
      );

      expect(preview.overwriteSampleKeys, ['k1', 'k2']);
      expect(preview.hiddenOverwriteCount, 0);
    });

    test('上書きキーは決定的に昇順ソートされる', () {
      final preview = RestorePreview.build(
        diffOf(overwrite: {'z': 1, 'a': 2, 'm': 3}),
      );

      expect(preview.overwriteSampleKeys, ['a', 'm', 'z']);
    });

    test('sampleLimit <= 0 は ArgumentError', () {
      expect(
        () => RestorePreview.build(diffOf(overwrite: {'a': 1}), sampleLimit: 0),
        throwsArgumentError,
      );
      expect(
        () =>
            RestorePreview.build(diffOf(overwrite: {'a': 1}), sampleLimit: -1),
        throwsArgumentError,
      );
    });
  });

  group('compose', () {
    test('Bundle と現状スナップショットから内訳を合成する', () {
      final bundle = BackupBundle(
        exportedAt: DateTime.utc(2026, 10, 7),
        entries: {
          'kozuchi_same': 'v',
          'kozuchi_changed': 'new',
          'kozuchi_only_in_backup': 1,
        },
      );

      final preview = compose(
        bundle: bundle,
        existing: {
          'kozuchi_same': 'v',
          'kozuchi_changed': 'old',
          'unrelated': 'ignored',
        },
      );

      expect(preview.created, 1);
      expect(preview.overwritten, 1);
      expect(preview.unchanged, 1);
      expect(preview.overwriteSampleKeys, ['kozuchi_changed']);
      expect(preview.summary, '新規 1件 / 上書き 1件 / 変更なし 1件');
    });
  });
}
