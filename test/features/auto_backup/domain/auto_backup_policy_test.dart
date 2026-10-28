import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/features/auto_backup/domain/auto_backup_policy.dart';

/// 自動バックアップのドメイン方針（実行可否・命名・世代整理）を検める試練。
void main() {
  group('AutoBackupPolicy.shouldRun', () {
    const policy = AutoBackupPolicy();
    final now = DateTime(2026, 10, 29, 12, 0);

    test('前回実行が無ければ実行する', () {
      expect(policy.shouldRun(lastAt: null, now: now), isTrue);
    });

    test('ちょうど24時間経過していれば実行する（境界を含む）', () {
      expect(
        policy.shouldRun(
          lastAt: now.subtract(const Duration(hours: 24)),
          now: now,
        ),
        isTrue,
      );
    });

    test('24時間未満なら実行しない', () {
      expect(
        policy.shouldRun(
          lastAt: now.subtract(const Duration(hours: 23, minutes: 59)),
          now: now,
        ),
        isFalse,
      );
    });

    test('前回実行が未来時刻でも実行する（時計ずれで停止しない）', () {
      expect(
        policy.shouldRun(lastAt: now.add(const Duration(hours: 3)), now: now),
        isTrue,
      );
    });

    test('interval / keep を差し替えられる', () {
      const short = AutoBackupPolicy(
        interval: Duration(hours: 1),
        keep: 5,
      );
      expect(short.interval, const Duration(hours: 1));
      expect(short.keep, 5);
      expect(
        short.shouldRun(
          lastAt: now.subtract(const Duration(minutes: 61)),
          now: now,
        ),
        isTrue,
      );
    });
  });

  group('AutoBackupPolicy.fileNameFor', () {
    test('ローカル暦でゼロ埋めした auto_backup_yyyyMMdd.json を返す', () {
      expect(
        AutoBackupPolicy.fileNameFor(DateTime(2026, 1, 5, 23, 59)),
        'auto_backup_20260105.json',
      );
      expect(
        AutoBackupPolicy.fileNameFor(DateTime(2026, 12, 31)),
        'auto_backup_20261231.json',
      );
    });

    test('UTC 変換せずローカルの日付を用いる', () {
      final local = DateTime(2026, 3, 1, 0, 30);
      expect(
        AutoBackupPolicy.fileNameFor(local),
        'auto_backup_20260301.json',
      );
    });

    test('isAutoBackupFile は自動バックアップ命名のみ真を返す', () {
      expect(AutoBackupPolicy.isAutoBackupFile('auto_backup_20260105.json'),
          isTrue);
      expect(AutoBackupPolicy.isAutoBackupFile('kozuchi_backup_20260105.json'),
          isFalse);
      expect(AutoBackupPolicy.isAutoBackupFile('auto_backup_20260105.csv'),
          isFalse);
      expect(AutoBackupPolicy.isAutoBackupFile('auto_backup_.json'), isFalse);
    });
  });

  group('AutoBackupPolicy.latestCreatedAt', () {
    test('空なら null、複数あれば最新を返す', () {
      const policy = AutoBackupPolicy();
      expect(policy.latestCreatedAt(const []), isNull);
      expect(
        policy.latestCreatedAt([
          AutoBackupEntry(
            fileName: 'auto_backup_20261001.json',
            createdAt: DateTime(2026, 10, 1),
          ),
          AutoBackupEntry(
            fileName: 'auto_backup_20261003.json',
            createdAt: DateTime(2026, 10, 3),
          ),
          AutoBackupEntry(
            fileName: 'auto_backup_20261002.json',
            createdAt: DateTime(2026, 10, 2),
          ),
        ]),
        DateTime(2026, 10, 3),
      );
    });
  });

  group('AutoBackupPolicy.prune', () {
    const policy = AutoBackupPolicy();
    AutoBackupEntry entry(String name, DateTime at) =>
        AutoBackupEntry(fileName: name, createdAt: at);

    test('keep 件を超えた分だけを削除対象として返す', () {
      final entries = [
        entry('auto_backup_20261001.json', DateTime(2026, 10, 1)),
        entry('auto_backup_20261002.json', DateTime(2026, 10, 2)),
        entry('auto_backup_20261003.json', DateTime(2026, 10, 3)),
        entry('auto_backup_20261004.json', DateTime(2026, 10, 4)),
      ];
      final pruned = policy.prune(entries);
      expect(pruned.map((e) => e.fileName), ['auto_backup_20261001.json']);
    });

    test('keep 件以下なら削除対象は無い', () {
      final entries = [
        entry('auto_backup_20261001.json', DateTime(2026, 10, 1)),
        entry('auto_backup_20261002.json', DateTime(2026, 10, 2)),
        entry('auto_backup_20261003.json', DateTime(2026, 10, 3)),
      ];
      expect(policy.prune(entries), isEmpty);
    });

    test('古い順（createdAt 昇順）に削除対象を並べる', () {
      final entries = [
        entry('auto_backup_20261005.json', DateTime(2026, 10, 5)),
        entry('auto_backup_20261001.json', DateTime(2026, 10, 1)),
        entry('auto_backup_20261003.json', DateTime(2026, 10, 3)),
        entry('auto_backup_20261002.json', DateTime(2026, 10, 2)),
        entry('auto_backup_20261004.json', DateTime(2026, 10, 4)),
      ];
      final pruned = policy.prune(entries).map((e) => e.fileName).toList();
      expect(pruned, [
        'auto_backup_20261001.json',
        'auto_backup_20261002.json',
      ]);
    });

    test('手動バックアップは削除対象に含めない（非破壊）', () {
      final entries = [
        entry('kozuchi_backup_20260101_0900.json', DateTime(2026, 1, 1)),
        entry('auto_backup_20261001.json', DateTime(2026, 10, 1)),
        entry('auto_backup_20261002.json', DateTime(2026, 10, 2)),
        entry('auto_backup_20261003.json', DateTime(2026, 10, 3)),
        entry('auto_backup_20261004.json', DateTime(2026, 10, 4)),
      ];
      final pruned = policy.prune(entries).map((e) => e.fileName).toList();
      expect(pruned, ['auto_backup_20261001.json']);
      expect(pruned, isNot(contains('kozuchi_backup_20260101_0900.json')));
    });

    test('createdAt が同じなら fileName 降順で順位を決める', () {
      final at = DateTime(2026, 10, 1);
      final entries = [
        entry('auto_backup_20260929.json', at),
        entry('auto_backup_20260928.json', at),
        entry('auto_backup_20261001.json', at),
        entry('auto_backup_20260930.json', at),
      ];
      final pruned = policy.prune(entries).map((e) => e.fileName).toList();
      // 同時刻なら fileName 降順で新しい3件（1001/0930/0929）を残す
      expect(pruned, ['auto_backup_20260928.json']);
    });
  });

  group('AutoBackupEntry', () {
    test('同値なら等価・hashCode も一致する', () {
      final a = AutoBackupEntry(
        fileName: 'auto_backup_20261029.json',
        createdAt: DateTime(2026, 10, 29),
      );
      final b = AutoBackupEntry(
        fileName: 'auto_backup_20261029.json',
        createdAt: DateTime(2026, 10, 29),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(
          AutoBackupEntry(
            fileName: 'auto_backup_20261029.json',
            createdAt: DateTime(2026, 10, 30),
          ),
        ),
      );
    });
  });
}
