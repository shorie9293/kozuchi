import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/domain/services/expense_aggregation_service.dart';
import 'package:kozuchi/features/category_ledger/domain/category_ledger.dart';

void main() {
  group('CategoryLedger', () {
    test('既定カテゴリで生成できる', () {
      final ledger = CategoryLedger.defaults();
      expect(
        ledger.categories,
        ExpenseAggregationService.defaultCategories,
      );
      expect(ledger.isDefault, isTrue);
      expect(ledger.length, ExpenseAggregationService.defaultCategories.length);
    });

    test('空リストは ArgumentError', () {
      expect(() => CategoryLedger([]), throwsArgumentError);
    });

    test('表示順を保持する', () {
      final ledger = CategoryLedger(['b', 'a', 'c']);
      expect(ledger.categories, ['b', 'a', 'c']);
    });

    test('isDefault: 1件追加すると false', () {
      final ledger = CategoryLedger.defaults();
      final added = CategoryLedger([...ledger.categories, 'ペット費']);
      expect(added.isDefault, isFalse);
    });

    test('isDefault: 順序が違えば false', () {
      final defaults = ExpenseAggregationService.defaultCategories;
      final swapped = [...defaults];
      final tmp = swapped[0];
      swapped[0] = swapped[1];
      swapped[1] = tmp;
      expect(CategoryLedger(swapped).isDefault, isFalse);
    });

    test('contains / length', () {
      final ledger = CategoryLedger.defaults();
      expect(ledger.contains('食費'), isTrue);
      expect(ledger.contains('ペット費'), isFalse);
      expect(ledger.length, 12);
    });

    group('tryFromJson', () {
      test('正常なリストは復元できる', () {
        final ledger = CategoryLedger.tryFromJson(['a', 'b']);
        expect(ledger, isNotNull);
        expect(ledger!.categories, ['a', 'b']);
      });

      test('空リストは null', () {
        expect(CategoryLedger.tryFromJson(<String>[]), isNull);
      });

      test('非文字列要素は null', () {
        expect(CategoryLedger.tryFromJson([1, 2]), isNull);
        expect(CategoryLedger.tryFromJson(['a', 1]), isNull);
      });

      test('List 以外は null', () {
        expect(CategoryLedger.tryFromJson('a'), isNull);
        expect(CategoryLedger.tryFromJson(123), isNull);
        expect(CategoryLedger.tryFromJson(null), isNull);
        expect(CategoryLedger.tryFromJson({'a': 1}), isNull);
      });
    });

    test('toJson → tryFromJson の往復', () {
      final ledger = CategoryLedger(['食費', '娯楽']);
      final restored = CategoryLedger.tryFromJson(ledger.toJson());
      expect(restored, ledger);
    });

    test('等価性・hashCode・toString', () {
      final a = CategoryLedger(['食費', '娯楽']);
      final b = CategoryLedger(['食費', '娯楽']);
      final c = CategoryLedger(['娯楽', '食費']);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
      expect(a.toString(), contains('食費'));
    });

    test('既定と異なるカテゴリの台帳は isDefault false', () {
      expect(CategoryLedger(['独自']).isDefault, isFalse);
    });
  });
}