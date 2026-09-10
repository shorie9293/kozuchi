import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/budget/domain/budget_rollover_service.dart';

void main() {
  const service = BudgetRolloverService();

  group('BudgetRolloverService.compute', () {
    test('前月の残額が繰り越される', () {
      final r = service.compute(
        baseBudget: 100000,
        previousBudget: 100000,
        previousSpent: 60000,
      );
      expect(r.carryOver, 40000);
      expect(r.effectiveBudget, 140000);
      expect(r.hasOverspend, isFalse);
    });

    test('前月を使い切った場合は中立', () {
      final r = service.compute(
        baseBudget: 100000,
        previousBudget: 100000,
        previousSpent: 100000,
      );
      expect(r.isNeutral, isTrue);
      expect(r.effectiveBudget, 100000);
    });

    test('前月が超過した場合は超過額を返し繰越しない', () {
      final r = service.compute(
        baseBudget: 100000,
        previousBudget: 100000,
        previousSpent: 120000,
      );
      expect(r.hasOverspend, isTrue);
      expect(r.overspend, 20000);
      expect(r.carryOver, 0);
      expect(r.effectiveBudget, 100000);
    });

    test('前月予算が未設定なら繰越も超過判定もしない', () {
      final r = service.compute(
        baseBudget: 100000,
        previousBudget: 0,
        previousSpent: 50000,
      );
      expect(r.isNeutral, isTrue);
      expect(r.effectiveBudget, 100000);
    });

    test('繰り越し無効時は残額を繰り越さない', () {
      final r = service.compute(
        baseBudget: 100000,
        previousBudget: 100000,
        previousSpent: 40000,
        enabled: false,
      );
      expect(r.carryOver, 0);
      expect(r.enabled, isFalse);
    });

    test('繰り越し無効でも超過警告は返す', () {
      final r = service.compute(
        baseBudget: 100000,
        previousBudget: 100000,
        previousSpent: 110000,
        enabled: false,
      );
      expect(r.overspend, 10000);
      expect(r.enabled, isFalse);
    });

    test('繰越上限で頭打ちになる', () {
      const capped = BudgetRolloverService(carryOverCap: 20000);
      final r = capped.compute(
        baseBudget: 100000,
        previousBudget: 100000,
        previousSpent: 40000,
      );
      expect(r.carryOver, 20000);
      expect(r.effectiveBudget, 120000);
    });

    test('繰越上限0なら繰り越さない', () {
      const capped = BudgetRolloverService(carryOverCap: 0);
      final r = capped.compute(
        baseBudget: 100000,
        previousBudget: 100000,
        previousSpent: 40000,
      );
      expect(r.carryOver, 0);
    });

    test('残額が上限以下ならそのまま繰り越す', () {
      const capped = BudgetRolloverService(carryOverCap: 50000);
      final r = capped.compute(
        baseBudget: 100000,
        previousBudget: 100000,
        previousSpent: 60000,
      );
      expect(r.carryOver, 40000);
    });

    test('負の基本予算は ArgumentError', () {
      expect(
        () => service.compute(
          baseBudget: -1,
          previousBudget: 0,
          previousSpent: 0,
        ),
        throwsArgumentError,
      );
    });

    test('負の前月支出は ArgumentError', () {
      expect(
        () => service.compute(
          baseBudget: 1000,
          previousBudget: 1000,
          previousSpent: -1,
        ),
        throwsArgumentError,
      );
    });
  });
}
