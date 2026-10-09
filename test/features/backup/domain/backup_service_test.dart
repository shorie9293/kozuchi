import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/features/backup/domain/backup_models.dart';
import 'package:kozuchi/features/backup/domain/backup_service.dart';

void main() {
  group('isBackupKey', () {
    test('kozuchi_ プレフィックスは許可', () {
      expect(BackupService.isBackupKey('kozuchi_expense_entries'), isTrue);
    });

    test('kozuchi 裸プレフィックスは許可', () {
      expect(BackupService.isBackupKey('kozuchiX'), isTrue);
    });

    test('rpg_bonus_daily_count_ プレフィックスは許可', () {
      expect(BackupService.isBackupKey('rpg_bonus_daily_count_quest'), isTrue);
    });

    test('完全一致キーは許可', () {
      for (final key in kBackupKeyExact) {
        expect(BackupService.isBackupKey(key), isTrue, reason: key);
      }
    });

    test('income_entries と notification_settings_v1 がバックアップ対象である', () {
      expect(BackupService.isBackupKey('income_entries'), isTrue);
      expect(BackupService.isBackupKey('notification_settings_v1'), isTrue);
      final bundle = const BackupService().build({
        'income_entries': <String>['2026-10-07|salary|10000'],
        'notification_settings_v1': 'enabled|9|0',
      });
      expect(bundle.entries.keys, containsAll(['income_entries', 'notification_settings_v1']));
      expect(bundle.entryCount, 2);
    });

    test('対象外キーは拒否', () {
      expect(BackupService.isBackupKey('flutter.abc'), isFalse);
      expect(BackupService.isBackupKey('Kozuchi_goals'), isFalse);
      expect(BackupService.isBackupKey('rpg_bonus_daily_count'), isFalse);
      expect(BackupService.isBackupKey(''), isFalse);
    });
  });

  group('build', () {
    test('対象キーのみ抽出し exportedAt は UTC', () {
      final service = BackupService(
        now: () => DateTime.utc(2026, 10, 7, 10, 0), // TZ非依存（実装が toUtc() する）
      );
      final bundle = service.build({
        'kozuchi_goals': <String>['a'],
        'kozuchi_count': 3,
        'flutter.xxx': 'ignored',
      });
      expect(bundle.entryCount, 2);
      expect(
        bundle.exportedAt,
        DateTime.utc(2026, 10, 7, 10, 0), // JST → UTC
      );
      expect(bundle.entries.containsKey('flutter.xxx'), isFalse);
    });

    test('非対象キー・対象外型の値はスキップ（例外を投げない）', () {
      final service = const BackupService();
      final bundle = service.build({
        'flutter.debug': 'x',
        'unrelated': 1,
        'kozuchi_map': <String, dynamic>{'a': 1}, // Map は対象外
        'kozuchi_nested_list': <dynamic>[1, 'x'], // 要素に非String
        'kozuchi_null': null,
        'kozuchi_keep': 'kept',
      });
      expect(bundle.entries, {'kozuchi_keep': 'kept'});
    });

    test('entries はキー昇順で並ぶ', () {
      final service = const BackupService();
      final bundle = service.build({
        'kozuchi_c': 1,
        'kozuchi_a': 2,
        'kozuchi_b': 3,
      });
      expect(bundle.entries.keys.toList(), ['kozuchi_a', 'kozuchi_b', 'kozuchi_c']);
    });

    test('double / bool / List<String> も採用される', () {
      final service = const BackupService();
      final bundle = service.build({
        'kozuchi_d': 1.5,
        'kozuchi_b': false,
        'kozuchi_l': <String>['x'],
      });
      expect(bundle.entries, {
        'kozuchi_d': 1.5,
        'kozuchi_b': false,
        'kozuchi_l': <String>['x'],
      });
    });
  });

  group('exportJson / parse', () {
    test('往復で entries が保たれる', () {
      final service = BackupService(now: () => DateTime.utc(2026, 10, 7));
      final bundle = service.build({
        'kozuchi_goals': <String>['a', 'b'],
        'kozuchi_count': 7,
      });
      final json = service.exportJson(bundle);
      expect(json, contains('  ')); // インデント整形
      final parsed = service.parse(json);
      expect(parsed.exportedAt, bundle.exportedAt);
      expect(parsed.entries, bundle.entries);
    });

    test('exportJson は JsonEncoder.withIndent と同型', () {
      final service = const BackupService();
      final bundle = BackupBundle(
        exportedAt: DateTime.utc(2026, 10, 7),
        entries: {'a': 1},
      );
      expect(
        service.exportJson(bundle),
        const JsonEncoder.withIndent('  ').convert(bundle.toJson()),
      );
    });

    test('破損JSON は FormatException', () {
      const service = BackupService();
      expect(() => service.parse('{not json'), throwsFormatException);
    });

    test('非オブジェクトJSON は FormatException', () {
      const service = BackupService();
      expect(() => service.parse('[1,2,3]'), throwsFormatException);
      expect(() => service.parse('"str"'), throwsFormatException);
    });

    test('entries の型不一致は FormatException', () {
      const service = BackupService();
      final source = jsonEncode({
        'schemaVersion': 1,
        'exportedAt': '2026-10-07T00:00:00Z',
        'entries': {'kozuchi_bad': {'nested': 1}},
      });
      expect(() => service.parse(source), throwsFormatException);
    });
  });

  group('diff', () {
    test('既存なし → 全て toCreate', () {
      final service = const BackupService();
      final bundle = BackupBundle(
        exportedAt: DateTime.utc(2026),
        entries: {'a': 1, 'b': 2},
      );
      final diff = service.diff(bundle: bundle, existing: {});
      expect(diff.created, 2);
      expect(diff.restored, 0);
      expect(diff.unchanged, 0);
      expect(diff.toCreate, {'a': 1, 'b': 2});
      expect(diff.result.total, 2);
    });

    test('値が異なる → toOverwrite', () {
      final service = const BackupService();
      final bundle = BackupBundle(
        exportedAt: DateTime.utc(2026),
        entries: {'a': 2},
      );
      final diff = service.diff(bundle: bundle, existing: {'a': 1});
      expect(diff.created, 0);
      expect(diff.restored, 1);
      expect(diff.unchanged, 0);
      expect(diff.toOverwrite, {'a': 2});
    });

    test('同値 → unchanged', () {
      final service = const BackupService();
      final bundle = BackupBundle(
        exportedAt: DateTime.utc(2026),
        entries: {'a': 1},
      );
      final diff = service.diff(bundle: bundle, existing: {'a': 1});
      expect(diff.created, 0);
      expect(diff.restored, 0);
      expect(diff.unchanged, 1);
    });

    test('3分岐の混在で result ラベルまで正しい', () {
      final service = const BackupService();
      final bundle = BackupBundle(
        exportedAt: DateTime.utc(2026),
        entries: {'new': 1, 'same': 'x', 'diff': 2.0},
      );
      final diff = service.diff(
        bundle: bundle,
        existing: {'same': 'x', 'diff': 1.0},
      );
      expect(diff.result.created, 1);
      expect(diff.result.restored, 1);
      expect(diff.result.unchanged, 1);
      expect(diff.result.label, '新規 1件 / 更新 1件 / 変更なし 1件');
    });

    test('List<String> は要素比較で同値判定される', () {
      final service = const BackupService();
      final bundle = BackupBundle(
        exportedAt: DateTime.utc(2026),
        entries: {
          'same': <String>['a', 'b'],
          'diff': <String>['a', 'c'],
          'len': <String>['a'],
        },
      );
      final diff = service.diff(bundle: bundle, existing: {
        'same': <String>['a', 'b'], // 別インスタンスでも同値
        'diff': <String>['a', 'b'],
        'len': <String>['a', 'b'],
      });
      expect(diff.unchanged, 1); // same のみ
      expect(diff.restored, 2); // diff / len
    });
  });

  group('suggestedFileName', () {
    test('ゼロ埋めのファイル名を返す', () {
      expect(
        BackupService.suggestedFileName(DateTime(2026, 10, 7, 19, 0)),
        'kozuchi_backup_20261007_1900.json',
      );
      expect(
        BackupService.suggestedFileName(DateTime(2026, 1, 2, 3, 4)),
        'kozuchi_backup_20260102_0304.json',
      );
    });
  });
}
