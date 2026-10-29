import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/features/auto_backup/domain/auto_backup_policy.dart';
import 'package:kozuchi/features/auto_backup/domain/auto_backup_presenter.dart';

/// 自動バックアップ一覧の表示整形（純粋計算）を検める試練。
void main() {
  group('formatDate', () {
    test('ローカル暦を yyyy-MM-dd HH:mm で整形する', () {
      expect(
        AutoBackupPresenter.formatDate(DateTime(2026, 10, 29, 7, 12)),
        '2026-10-29 07:12',
      );
    });

    test('1桁の月日時分はゼロ埋めする', () {
      expect(
        AutoBackupPresenter.formatDate(DateTime(2026, 1, 5, 0, 3)),
        '2026-01-05 00:03',
      );
    });
  });

  group('formatSize', () {
    test('1024未満は B 表記', () {
      expect(AutoBackupPresenter.formatSize(0), '0 B');
      expect(AutoBackupPresenter.formatSize(512), '512 B');
      expect(AutoBackupPresenter.formatSize(1023), '1023 B');
    });

    test('1024以上は KB 表記（小数1桁・1024基数）', () {
      expect(AutoBackupPresenter.formatSize(1024), '1.0 KB');
      expect(AutoBackupPresenter.formatSize(12698), '12.4 KB');
    });

    test('1024KB 以上は MB 表記（小数1桁）', () {
      expect(AutoBackupPresenter.formatSize(1024 * 1024), '1.0 MB');
      expect(AutoBackupPresenter.formatSize(1258291), '1.2 MB');
    });
  });

  group('canRestore', () {
    test('JSONオブジェクトなら true', () {
      expect(AutoBackupPresenter.canRestore('{"exportedAt":"x"}'), isTrue);
      expect(AutoBackupPresenter.canRestore('{}'), isTrue);
    });

    test('null・空・空白のみは false', () {
      expect(AutoBackupPresenter.canRestore(null), isFalse);
      expect(AutoBackupPresenter.canRestore(''), isFalse);
      expect(AutoBackupPresenter.canRestore('   '), isFalse);
    });

    test('壊れたJSON・トップがオブジェクトでない場合は false（例外を投げない）', () {
      expect(AutoBackupPresenter.canRestore('{broken'), isFalse);
      expect(AutoBackupPresenter.canRestore('[1,2,3]'), isFalse);
      expect(AutoBackupPresenter.canRestore('"文字列"'), isFalse);
      expect(AutoBackupPresenter.canRestore('null'), isFalse);
      expect(AutoBackupPresenter.canRestore('42'), isFalse);
    });
  });

  group('sortNewestFirst', () {
    test('createdAt 降順・同時刻は fileName 降順', () {
      final entries = <AutoBackupEntry>[
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
      ];

      final sorted = AutoBackupPresenter.sortNewestFirst(entries);

      expect(
        sorted.map((e) => e.fileName).toList(),
        [
          'auto_backup_20261003.json',
          'auto_backup_20261002.json',
          'auto_backup_20261001.json',
        ],
      );
      // 元のリストは破壊しない
      expect(entries.first.fileName, 'auto_backup_20261001.json');
    });

    test('同時刻なら fileName 降順で安定する', () {
      final at = DateTime(2026, 10, 1);
      final sorted = AutoBackupPresenter.sortNewestFirst(<AutoBackupEntry>[
        AutoBackupEntry(fileName: 'auto_backup_20261001.json', createdAt: at),
        AutoBackupEntry(fileName: 'auto_backup_20260930.json', createdAt: at),
      ]);

      expect(
        sorted.map((e) => e.fileName).toList(),
        ['auto_backup_20261001.json', 'auto_backup_20260930.json'],
      );
    });
  });

  test('retentionLabel は保持世代数と件数を示す', () {
    expect(const AutoBackupPresenter().retentionLabel(2), '保持 3世代中 2件');
    expect(
      const AutoBackupPresenter(keep: 5).retentionLabel(0),
      '保持 5世代中 0件',
    );
  });

  group('buildRows', () {
    const presenter = AutoBackupPresenter();

    test('自動ファイルのみ・新しい順・第1世代が最新', () {
      final entries = <AutoBackupEntry>[
        AutoBackupEntry(
          fileName: 'auto_backup_20261001.json',
          createdAt: DateTime(2026, 10, 1),
        ),
        AutoBackupEntry(
          fileName: 'auto_backup_20261003.json',
          createdAt: DateTime(2026, 10, 3),
        ),
        AutoBackupEntry(
          fileName: 'kozuchi_backup_20261004_0900.json',
          createdAt: DateTime(2026, 10, 4),
        ),
      ];
      final contents = <String, String?>{
        'auto_backup_20261001.json': '{"a":1}',
        'auto_backup_20261003.json': '{"b":22}',
        'kozuchi_backup_20261004_0900.json': '{"c":333}',
      };

      final rows = presenter.buildRows(entries: entries, contents: contents);

      expect(rows.length, 2);
      expect(rows.first.entry.fileName, 'auto_backup_20261003.json');
      expect(rows.first.generation, 1);
      expect(rows.last.generation, 2);
      expect(rows.first.byteSize, '{"b":22}'.length);
      expect(rows.first.restorable, isTrue);
    });

    test('内容が無い・壊れたJSONは restorable=false・byteSize=0', () {
      final rows = presenter.buildRows(
        entries: <AutoBackupEntry>[
          AutoBackupEntry(
            fileName: 'auto_backup_20261003.json',
            createdAt: DateTime(2026, 10, 3),
          ),
          AutoBackupEntry(
            fileName: 'auto_backup_20261002.json',
            createdAt: DateTime(2026, 10, 2),
          ),
        ],
        contents: <String, String?>{
          'auto_backup_20261003.json': null,
          'auto_backup_20261002.json': '{broken',
        },
      );

      expect(rows.first.restorable, isFalse);
      expect(rows.first.byteSize, 0);
      expect(rows.last.restorable, isFalse);
    });

    test('byteSize は utf8 のバイト長（マルチバイトを数える）', () {
      final rows = presenter.buildRows(
        entries: <AutoBackupEntry>[
          AutoBackupEntry(
            fileName: 'auto_backup_20261003.json',
            createdAt: DateTime(2026, 10, 3),
          ),
        ],
        contents: <String, String?>{'auto_backup_20261003.json': '{"a":"日"}'},
      );

      // {"a":"日"} は ASCII 8 文字 + 日(3バイト) = 11
      expect(rows.single.byteSize, 11);
    });

    test('displayLabel は 日時 / サイズ / 世代 を並べる', () {
      final rows = presenter.buildRows(
        entries: <AutoBackupEntry>[
          AutoBackupEntry(
            fileName: 'auto_backup_20261029.json',
            createdAt: DateTime(2026, 10, 29, 7, 12),
          ),
        ],
        contents: <String, String?>{
          'auto_backup_20261029.json': 'x' * 12698,
        },
      );

      expect(rows.single.displayLabel, '2026-10-29 07:12 / 12.4 KB / 第1世代');
      expect(rows.single.dateLabel, '2026-10-29 07:12');
      expect(rows.single.sizeLabel, '12.4 KB');
    });

    test('0件なら空', () {
      expect(presenter.buildRows(entries: const [], contents: const {}), isEmpty);
    });
  });
}
