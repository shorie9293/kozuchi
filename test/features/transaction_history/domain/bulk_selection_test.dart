import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/transaction_history/domain/bulk_selection.dart';

/// 取引履歴の一括選択を支える純粋値オブジェクトの試練。
///
/// 仕様:
/// - [BulkSelection] は挿入順を保ち、元インスタンスを破壊しない
/// - [buildBulkDeletePlan] は「画面に表示中（visible）」の取引だけを対象にし、
///   絞込外の取引を巻き込まない
TransactionModel tx(String id) => TransactionModel(
      id: id,
      amount: -100,
      purpose: 'purpose-$id',
      category: '食費',
      datetime: '2026-11-01T12:00:00',
    );

void main() {
  group('BulkSelection', () {
    test('初期状態は未選択で count 0・contains は false', () {
      const selection = BulkSelection.empty();

      expect(selection.isSelecting, isFalse);
      expect(selection.count, 0);
      expect(selection.ids, isEmpty);
      expect(selection.contains('a'), isFalse);
    });

    test('toggle は追加と削除を往復し、元インスタンスを破壊しない', () {
      const base = BulkSelection.empty();

      final added = base.toggle('a');

      expect(added.count, 1);
      expect(added.contains('a'), isTrue);
      expect(added.isSelecting, isTrue);
      expect(base.count, 0, reason: '元インスタンスは不変');
      expect(base.contains('a'), isFalse);

      final removed = added.toggle('a');

      expect(removed.count, 0);
      expect(removed.contains('a'), isFalse);
      expect(removed, const BulkSelection.empty());
      expect(added.count, 1, reason: '削除元も不変');
    });

    test('of は重複を畳み、挿入順を保つ', () {
      final selection = BulkSelection.of(['b', 'a', 'b']);

      expect(selection.count, 2);
      expect(selection.ids, ['b', 'a']);
    });

    test('selectAll は既存順を保ち、重複を足さない', () {
      final base = BulkSelection.of(['b', 'a']);

      final merged = base.selectAll(['a', 'c', 'c', 'b']);

      expect(merged.ids, ['b', 'a', 'c']);
      expect(merged.count, 3);
      expect(base.count, 2, reason: '元インスタンスは不変');
      expect(base.contains('c'), isFalse);
    });

    test('ids は変更不可（unmodifiable）', () {
      final selection = BulkSelection.of(['a']);

      expect(() => selection.ids.add('b'), throwsUnsupportedError);
      expect(selection.count, 1);
    });

    test('clear は空の新しいインスタンスを返し、元は不変', () {
      final base = BulkSelection.of(['a', 'b']);

      final cleared = base.clear();

      expect(cleared, const BulkSelection.empty());
      expect(cleared.isSelecting, isFalse);
      expect(base.count, 2);
    });

    test('== と hashCode は順序に依存しない集合等価', () {
      final ab = BulkSelection.of(['a', 'b']);
      final ba = BulkSelection.of(['b', 'a']);

      expect(ab, ba);
      expect(ab.hashCode, ba.hashCode);
      expect(ab, isNot(BulkSelection.of(['a'])));
      expect(ab, isNot(BulkSelection.of(['a', 'b', 'c'])));
      expect(const BulkSelection.empty(), BulkSelection.of(const []));
      const Object notASelection = 'a';
      expect(ab == notASelection, isFalse);
    });
  });

  group('buildBulkDeletePlan', () {
    test('選択が visible の部分集合なら unknownIds は空で、visible の元順序を保つ', () {
      final visible = [tx('a'), tx('b'), tx('c')];
      final selection = BulkSelection.of(['c', 'a']);

      final plan = buildBulkDeletePlan(visible: visible, selection: selection);

      expect(plan.toDelete.map((t) => t.id), ['a', 'c']);
      expect(plan.unknownIds, isEmpty);
    });

    test('visible に無いIDは unknownIds に入り、toDelete には入らない', () {
      // 絞込中に「表示されていない取引」が選択に混ざっている状況。
      final visible = [tx('a'), tx('b')];
      final selection = BulkSelection.of(['a', 'hidden-1', 'b', 'hidden-2']);

      final plan = buildBulkDeletePlan(visible: visible, selection: selection);

      expect(plan.toDelete.map((t) => t.id), ['a', 'b'],
          reason: '絞込外の取引を巻き込まない');
      expect(plan.unknownIds, ['hidden-1', 'hidden-2']);
    });

    test('選択が空なら削除対象も空', () {
      final plan = buildBulkDeletePlan(
        visible: [tx('a')],
        selection: const BulkSelection.empty(),
      );

      expect(plan.toDelete, isEmpty);
      expect(plan.unknownIds, isEmpty);
    });

    test('id の無い取引は選択対象になり得ないため plan に現れない', () {
      final visible = [
        const TransactionModel(
          amount: -100,
          purpose: 'no id',
          category: '食費',
          datetime: '2026-11-01T12:00:00',
        ),
        tx('a'),
      ];

      final plan = buildBulkDeletePlan(
          visible: visible, selection: BulkSelection.of(['a']));

      expect(plan.toDelete.map((t) => t.id), ['a']);
      expect(plan.unknownIds, isEmpty);
    });
  });
}
