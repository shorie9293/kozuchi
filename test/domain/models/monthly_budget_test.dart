import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/monthly_budget.dart';

void main() {
  group('MonthlyBudget', () {
    test('年月と予算額を指定して生成できる', () {
      final budget = MonthlyBudget(yearMonth: '2026-06', amount: 150000);
      expect(budget.yearMonth, '2026-06');
      expect(budget.amount, 150000);
    });

    test('デフォルト予算額は0', () {
      final budget = MonthlyBudget(yearMonth: '2026-06');
      expect(budget.amount, 0);
    });

    test('予算額が0の場合は未設定状態と判定される', () {
      final budget = MonthlyBudget(yearMonth: '2026-06', amount: 0);
      expect(budget.isNotSet, isTrue);
    });

    test('予算額が正の場合は設定済み状態と判定される', () {
      final budget = MonthlyBudget(yearMonth: '2026-06', amount: 100000);
      expect(budget.isNotSet, isFalse);
    });

    test('JSONに変換して復元できる', () {
      final original = MonthlyBudget(yearMonth: '2026-07', amount: 200000);
      final json = original.toJson();
      final restored = MonthlyBudget.fromJson(json);

      expect(restored.yearMonth, '2026-07');
      expect(restored.amount, 200000);
    });

    test('JSONのamountが欠落している場合は0で復元される', () {
      final restored = MonthlyBudget.fromJson({'yearMonth': '2026-06'});
      expect(restored.yearMonth, '2026-06');
      expect(restored.amount, 0);
    });

    test('JSONのyearMonthが欠落している場合は空文字で復元される', () {
      final restored = MonthlyBudget.fromJson({'amount': 50000});
      expect(restored.yearMonth, '');
      expect(restored.amount, 50000);
    });

    test('空のJSONからは空のMonthlyBudgetが復元される', () {
      final restored = MonthlyBudget.fromJson({});
      expect(restored.yearMonth, '');
      expect(restored.amount, 0);
    });

    test('現在の年月を取得できる（YYYY-MM形式）', () {
      final currentMonth = MonthlyBudget.currentYearMonth();
      // 形式チェック: YYYY-MM
      expect(currentMonth, matches(RegExp(r'^\d{4}-\d{2}$')));
    });

    test('copyWithで予算額のみ更新できる', () {
      final original = MonthlyBudget(yearMonth: '2026-06', amount: 100000);
      final updated = original.copyWith(amount: 150000);

      expect(updated.yearMonth, '2026-06');
      expect(updated.amount, 150000);
      // 元のオブジェクトは不変
      expect(original.amount, 100000);
    });
  });
}
