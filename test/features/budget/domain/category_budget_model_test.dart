import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/category_budget.dart';

void main() {
  group('CategoryBudget', () {
    test('コンストラクタで category と amount を設定できる', () {
      const b = CategoryBudget(category: '食費', amount: 50000);
      expect(b.category, '食費');
      expect(b.amount, 50000);
      expect(b.isNotSet, isFalse);
    });

    test('amount デフォルト0・isNotSet true', () {
      const b = CategoryBudget(category: '趣味');
      expect(b.amount, 0);
      expect(b.isNotSet, isTrue);
    });

    test('toJson/fromJson 往復で復元される', () {
      const b = CategoryBudget(category: '食費', amount: 50000);
      final restored = CategoryBudget.fromJson(b.toJson());
      expect(restored.category, '食費');
      expect(restored.amount, 50000);
    });

    test('copyWith で amount のみ更新され元は不変', () {
      const b = CategoryBudget(category: '食費', amount: 50000);
      final b2 = b.copyWith(amount: 60000);
      expect(b2.amount, 60000);
      expect(b2.category, '食費');
      expect(b.amount, 50000);
    });

    test('負の金額は assert で弾かれる', () {
      expect(
        () => CategoryBudget(category: '食費', amount: -1),
        throwsAssertionError,
      );
    });
  });
}
