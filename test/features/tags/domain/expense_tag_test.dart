import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/tags/domain/models/expense_tag.dart';
import 'package:kozuchi/features/tags/domain/models/tagged_transaction.dart';

void main() {
  group('ExpenseTag', () {
    test('既定色は defaultColorValue', () {
      const tag = ExpenseTag(id: 't1', name: '旅行');
      expect(tag.colorValue, ExpenseTag.defaultColorValue);
    });

    test('copyWith は指定フィールドのみ変更する', () {
      const tag = ExpenseTag(id: 't1', name: '旅行', colorValue: 0xFF00FF00);
      final renamed = tag.copyWith(name: '国内旅行');
      expect(renamed.id, 't1');
      expect(renamed.name, '国内旅行');
      expect(renamed.colorValue, 0xFF00FF00);
    });

    test('JSON 往復で等価', () {
      const tag = ExpenseTag(id: 't9', name: 'サブスク', colorValue: 0xFF112233);
      final restored = ExpenseTag.fromJson(tag.toJson());
      expect(restored, tag);
    });

    test('fromJson は欠損フィールドを既定値で補完する', () {
      final tag = ExpenseTag.fromJson(<String, dynamic>{'id': 't2'});
      expect(tag.id, 't2');
      expect(tag.name, '');
      expect(tag.colorValue, ExpenseTag.defaultColorValue);
    });

    test('等価判定と hashCode は全フィールドを見る', () {
      const a = ExpenseTag(id: 't1', name: '旅行');
      const b = ExpenseTag(id: 't1', name: '旅行');
      const c = ExpenseTag(id: 't1', name: '出張');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
    });
  });

  group('TaggedTransaction', () {
    TransactionModel tx() => const TransactionModel(
          amount: -1200,
          purpose: 'ランチ',
          category: '食費',
          datetime: '2026-09-12T12:30:00',
        );

    test('keyOfTransaction は datetime|amount|purpose|category 形式', () {
      expect(
        TaggedTransaction.keyOfTransaction(tx()),
        '2026-09-12T12:30:00|-1200|ランチ|食費',
      );
    });

    test('同じ取引からは同じキーが生成される', () {
      expect(
        TaggedTransaction.keyOfTransaction(tx()),
        TaggedTransaction.keyOfTransaction(tx()),
      );
    });

    test('copyWith は重複タグIDを除去する', () {
      final t = TaggedTransaction.of(tx(), tagIds: const ['a', 'a', 'b']);
      expect(t.tagIds, ['a', 'b']);
    });

    test('空文字のタグIDは保持しない', () {
      final t = TaggedTransaction.of(tx(), tagIds: const ['a', '']);
      expect(t.tagIds, ['a']);
    });

    test('isUntagged / hasTag', () {
      final none = TaggedTransaction.of(tx());
      expect(none.isUntagged, isTrue);
      expect(none.hasTag('a'), isFalse);

      final tagged = TaggedTransaction.of(tx(), tagIds: const ['a', 'b']);
      expect(tagged.isUntagged, isFalse);
      expect(tagged.hasTag('b'), isTrue);
    });

    test('JSON 往復で等価（重複は正規化）', () {
      final t = TaggedTransaction.of(tx(), tagIds: const ['a', 'b']);
      expect(TaggedTransaction.fromJson(t.toJson()), t);
    });

    test('fromJson は不正な tags を空リストにする', () {
      final t = TaggedTransaction.fromJson(<String, dynamic>{
        'key': 'k',
        'tags': 'not-a-list',
      });
      expect(t.transactionKey, 'k');
      expect(t.tagIds, isEmpty);
    });
  });
}
