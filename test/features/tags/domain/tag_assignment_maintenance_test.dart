import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/tags/domain/tag_assignment_maintenance.dart';

void main() {
  group('TagAssignmentBackup', () {
    test('重複したタグIDと空文字を取り除く', () {
      final backup = TagAssignmentBackup.of(
        transactionKey: 'k1',
        tagIds: const ['t1', '', 't1', 't2'],
      );
      expect(backup.tagIds, ['t1', 't2']);
      expect(backup.isEmpty, isFalse);
      expect(backup.matches('k1'), isTrue);
      expect(backup.matches('k2'), isFalse);
    });

    test('空リストなら isEmpty', () {
      final backup = TagAssignmentBackup.of(
        transactionKey: 'k1',
        tagIds: const [],
      );
      expect(backup.isEmpty, isTrue);
      expect(backup.tagIds, isEmpty);
    });

    test('空文字だけなら isEmpty', () {
      final backup = TagAssignmentBackup.of(
        transactionKey: 'k1',
        tagIds: const ['', ''],
      );
      expect(backup.isEmpty, isTrue);
    });

    test('tagIds は変更不可', () {
      final backup = TagAssignmentBackup.of(
        transactionKey: 'k1',
        tagIds: const ['t1'],
      );
      expect(
        () => backup.tagIds.add('t2'),
        throwsUnsupportedError,
      );
    });
  });

  group('TagAssignmentPrune.orphanKeys', () {
    final assignments = <String, List<String>>{
      'b': ['t1'],
      'a': ['t2'],
      'gone': ['t3'],
      '': ['t4'],
    };

    test('既知集合に無いキーのみをソート順で返す', () {
      final orphans = TagAssignmentPrune.orphanKeys(
        knownTransactionKeys: const ['a', 'b'],
        assignments: assignments,
      );
      expect(orphans, ['gone']);
    });

    test('空キーは対象外', () {
      final orphans = TagAssignmentPrune.orphanKeys(
        knownTransactionKeys: const ['a', 'b', 'gone'],
        assignments: assignments,
      );
      expect(orphans, isEmpty);
    });

    test('既知が空なら全キーが孤児（空キーを除く）', () {
      final orphans = TagAssignmentPrune.orphanKeys(
        knownTransactionKeys: const [],
        assignments: assignments,
      );
      expect(orphans, ['a', 'b', 'gone']);
    });

    test('元マップを破壊しない', () {
      final original = <String, List<String>>{
        'a': ['t1'],
        'gone': ['t2'],
      };
      TagAssignmentPrune.orphanKeys(
        knownTransactionKeys: const ['a'],
        assignments: original,
      );
      expect(original.keys.toList(), ['a', 'gone']);
    });
  });

  group('TagAssignmentPrune.prune', () {
    test('孤児のみ取り除いた新マップを返す', () {
      final original = <String, List<String>>{
        'a': ['t1'],
        'gone': ['t2'],
      };
      final pruned = TagAssignmentPrune.prune(
        knownTransactionKeys: const ['a'],
        assignments: original,
      );
      expect(pruned.keys.toList(), ['a']);
      expect(pruned['a'], ['t1']);
      // 元マップは非破壊
      expect(original.containsKey('gone'), isTrue);
    });

    test('孤児が無ければ同じ内容を返す', () {
      final original = <String, List<String>>{
        'a': ['t1'],
        'b': ['t2'],
      };
      final pruned = TagAssignmentPrune.prune(
        knownTransactionKeys: const ['a', 'b'],
        assignments: original,
      );
      expect(pruned, original);
    });
  });

  group('TagAssignmentPrune.canPrune', () {
    test('空なら false（全紐付け消失の安全弁）', () {
      expect(TagAssignmentPrune.canPrune(const []), isFalse);
    });

    test('空文字のみなら false', () {
      expect(TagAssignmentPrune.canPrune(const ['']), isFalse);
    });

    test('非空が1件でもあれば true', () {
      expect(TagAssignmentPrune.canPrune(const ['a']), isTrue);
    });
  });
}
