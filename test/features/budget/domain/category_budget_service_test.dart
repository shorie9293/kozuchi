import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/budget/domain/category_budget_service.dart';
import 'package:kozuchi/features/budget/domain/category_budget_status.dart';

void main() {
  const service = CategoryBudgetService(); // 警告閾値 0.8

  group('CategoryBudgetService.evaluate', () {
    test('予算未設定カテゴリは結果に含まれない', () {
      final result = service.evaluate(
        categoryBudgets: {'食費': 0, '趣味': 10000},
        categorySpent: {'食費': 5000, '趣味': 0},
      );
      expect(result.map((s) => s.category), ['趣味']);
    });

    test('閾値未満は ok', () {
      final result = service.evaluate(
        categoryBudgets: {'食費': 10000},
        categorySpent: {'食費': 5000},
      );
      expect(result.single.state, CategoryBudgetState.ok);
      expect(result.single.ratio, closeTo(0.5, 0.0001));
    });

    test('80%以上100%未満は warning', () {
      final result = service.evaluate(
        categoryBudgets: {'食費': 10000},
        categorySpent: {'食費': 8000},
      );
      expect(result.single.state, CategoryBudgetState.warning);
    });

    test('100%以上は exceeded', () {
      final r1 = service.evaluate(
        categoryBudgets: {'食費': 10000},
        categorySpent: {'食費': 10000},
      );
      final r2 = service.evaluate(
        categoryBudgets: {'食費': 10000},
        categorySpent: {'食費': 12000},
      );
      expect(r1.single.state, CategoryBudgetState.exceeded);
      expect(r2.single.state, CategoryBudgetState.exceeded);
    });

    test('支出が無いカテゴリは spent 0・ok', () {
      final result = service.evaluate(
        categoryBudgets: {'食費': 10000},
        categorySpent: {},
      );
      expect(result.single.spent, 0);
      expect(result.single.state, CategoryBudgetState.ok);
    });

    test('warningThreshold をカスタム指定できる', () {
      const custom = CategoryBudgetService(warningThreshold: 0.5);
      final result = custom.evaluate(
        categoryBudgets: {'食費': 10000},
        categorySpent: {'食費': 6000},
      );
      expect(result.single.state, CategoryBudgetState.warning);
    });
  });

  group('ヘルパー', () {
    test('hasExceeded で超過有無を判定', () {
      expect(
        service.hasExceeded(
          categoryBudgets: {'食費': 10000},
          categorySpent: {'食費': 12000},
        ),
        isTrue,
      );
      expect(
        service.hasExceeded(
          categoryBudgets: {'食費': 10000},
          categorySpent: {'食費': 5000},
        ),
        isFalse,
      );
    });

    test('exceeded / warnings を正しくフィルタ', () {
      final exceeded = service.exceeded(
        categoryBudgets: {'食費': 10000, '趣味': 10000},
        categorySpent: {'食費': 12000, '趣味': 9000},
      );
      expect(exceeded.map((s) => s.category), ['食費']);

      final warnings = service.warnings(
        categoryBudgets: {'食費': 10000, '趣味': 10000},
        categorySpent: {'食費': 12000, '趣味': 9000},
      );
      expect(warnings.map((s) => s.category), ['趣味']);
    });
  });
}
