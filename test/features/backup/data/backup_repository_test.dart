import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kozuchi/features/backup/domain/backup_models.dart';
import 'package:kozuchi/features/backup/domain/backup_service.dart';
import 'package:kozuchi/features/backup/data/backup_repository.dart';

void main() {
  group('SharedPreferencesBackupRepository', () {
    test('collect → exportJson → parse → restore の往復が保たれる', () async {
      SharedPreferences.setMockInitialValues({
        'kozuchi_expense_entries': '[{"amount":100}]',
        'kozuchi_goals': <String>['g1', 'g2'],
        'kozuchi_ratio': 0.5,
        'kozuchi_flag': true,
        'kozuchi_count': 3,
        'goals': 'exact-key',
        'flutter.xxx': 'ignored',
        'unrelated': 1,
      });

      final repo = SharedPreferencesBackupRepository(
        now: () => DateTime(2026, 10, 7, 19, 0),
      );
      final bundle = await repo.collect();
      expect(bundle.entryCount, 6);
      expect(bundle.entries.containsKey('flutter.xxx'), isFalse);

      // JSON 往復
      final service = const BackupService();
      final restored = service.parse(service.exportJson(bundle));
      expect(restored.entries, bundle.entries);

      // 全消去後に入れ直す
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      SharedPreferences.setMockInitialValues(<String, Object>{});

      final result = await repo.restore(restored);
      expect(result.created, 6);
      expect(result.restored, 0);
      expect(result.unchanged, 0);

      final after = await SharedPreferences.getInstance();
      expect(after.getString('kozuchi_expense_entries'), '[{"amount":100}]');
      expect(after.getStringList('kozuchi_goals'), <String>['g1', 'g2']);
      expect(after.getDouble('kozuchi_ratio'), 0.5);
      expect(after.getBool('kozuchi_flag'), isTrue);
      expect(after.getInt('kozuchi_count'), 3);
      expect(after.getString('goals'), 'exact-key');
      expect(after.getKeys().contains('flutter.xxx'), isFalse);
    });

    test('restore は新規/更新/変更なしを正しく振り分ける', () async {
      SharedPreferences.setMockInitialValues({
        'kozuchi_same': 'keep',
        'kozuchi_diff': 'old',
      });
      final repo = SharedPreferencesBackupRepository();
      final bundle = BackupBundle(
        exportedAt: DateTime.utc(2026),
        entries: {
          'kozuchi_same': 'keep',
          'kozuchi_diff': 'new',
          'kozuchi_add': 'added',
        },
      );
      final result = await repo.restore(bundle);
      expect(result.created, 1);
      expect(result.restored, 1);
      expect(result.unchanged, 1);
      expect(result.total, 3);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('kozuchi_diff'), 'new');
      expect(prefs.getString('kozuchi_add'), 'added');
      expect(prefs.getString('kozuchi_same'), 'keep');
    });

    test('restore: List<String> は同値なら setStringList しない', () async {
      SharedPreferences.setMockInitialValues({
        'kozuchi_list': <String>['a'],
      });
      final repo = SharedPreferencesBackupRepository();
      final bundle = BackupBundle(
        exportedAt: DateTime.utc(2026),
        entries: {
          'kozuchi_list': <String>['a'], // 別インスタンスだが同値
        },
      );
      final result = await repo.restore(bundle);
      expect(result.unchanged, 1);
      expect(result.created, 0);
      expect(result.restored, 0);
    });
  });

  group('InMemoryBackupRepository', () {
    test('collect は store から対象のみ採取する', () async {
      final repo = InMemoryBackupRepository({
        'kozuchi_a': 1,
        'flutter.x': 'no',
      });
      final bundle = await repo.collect();
      expect(bundle.entries, {'kozuchi_a': 1});
    });

    test('restore は store へ差分を書き戻す', () async {
      final store = {'kozuchi_same': 'x'};
      final repo = InMemoryBackupRepository(store);
      final bundle = BackupBundle(
        exportedAt: DateTime.utc(2026),
        entries: {
          'kozuchi_same': 'x',
          'kozuchi_new1': 'v1',
          'kozuchi_new2': 'v2',
        },
      );
      final result = await repo.restore(bundle);
      expect(result.created, 2);
      expect(result.restored, 0);
      expect(result.unchanged, 1);
      expect(store, {
        'kozuchi_same': 'x',
        'kozuchi_new1': 'v1',
        'kozuchi_new2': 'v2',
      });
    });

    test('既定コンストラクタで空 store が生成される', () async {
      final repo = InMemoryBackupRepository();
      final bundle = await repo.collect();
      expect(bundle.isEmpty, isTrue);
    });
  });

  group('NoopBackupRepository', () {
    test('collect は空バンドルを返す', () async {
      const repo = NoopBackupRepository();
      final bundle = await repo.collect();
      expect(bundle.isEmpty, isTrue);
      expect(bundle.entryCount, 0);
    });

    test('restore は全0の結果を返す', () async {
      const repo = NoopBackupRepository();
      final result = await repo.restore(
        BackupBundle(exportedAt: DateTime.utc(2026), entries: {'a': 1}),
      );
      expect(result.created, 0);
      expect(result.restored, 0);
      expect(result.unchanged, 0);
      expect(result.total, 0);
    });
  });
}
