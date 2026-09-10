import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/budget/domain/budget_rollover.dart';

void main() {
  group('BudgetRollover', () {
    test('実質予算は基本予算＋繰越額', () {
      const r = BudgetRollover(baseBudget: 100000, carryOver: 20000);
      expect(r.effectiveBudget, 120000);
    });

    test('繰越・超過の有無を判定できる', () {
      const withCarry = BudgetRollover(baseBudget: 100000, carryOver: 5000);
      const withOver = BudgetRollover(baseBudget: 100000, overspend: 3000);
      const neutral = BudgetRollover(baseBudget: 100000);

      expect(withCarry.hasCarryOver, isTrue);
      expect(withCarry.hasOverspend, isFalse);
      expect(withOver.hasOverspend, isTrue);
      expect(withOver.hasCarryOver, isFalse);
      expect(neutral.isNeutral, isTrue);
      expect(withCarry.isNeutral, isFalse);
    });

    test('ratioOf は実質予算に対する比率を返す', () {
      const r = BudgetRollover(baseBudget: 80000, carryOver: 20000);
      expect(r.ratioOf(50000), closeTo(0.5, 0.0001));
      expect(r.ratioOf(100000), closeTo(1.0, 0.0001));
    });

    test('ratioOf は実質予算0なら0を返す', () {
      const r = BudgetRollover(baseBudget: 0);
      expect(r.ratioOf(1000), 0);
    });

    test('JSON往復で復元される', () {
      const r = BudgetRollover(
        baseBudget: 150000,
        carryOver: 12000,
        overspend: 0,
        enabled: true,
        cap: 50000,
      );
      final restored = BudgetRollover.fromJson(r.toJson());
      expect(restored.baseBudget, 150000);
      expect(restored.carryOver, 12000);
      expect(restored.enabled, isTrue);
      expect(restored.cap, 50000);
    });

    test('cap が null の場合は JSON に含まれない', () {
      const r = BudgetRollover(baseBudget: 1000);
      expect(r.toJson().containsKey('cap'), isFalse);
      expect(BudgetRollover.fromJson(r.toJson()).cap, isNull);
    });
  });

  group('RolloverSettings', () {
    test('デフォルトは繰り越し無効・上限なし', () {
      expect(RolloverSettings.defaults.enabled, isFalse);
      expect(RolloverSettings.defaults.cap, isNull);
    });

    test('copyWith で有効化できる', () {
      final s = RolloverSettings.defaults.copyWith(enabled: true, cap: 30000);
      expect(s.enabled, isTrue);
      expect(s.cap, 30000);
    });

    test('copyWith clearCap で上限を解除できる', () {
      const s = RolloverSettings(enabled: true, cap: 30000);
      expect(s.copyWith(clearCap: true).cap, isNull);
    });

    test('JSON往復で復元される', () {
      const s = RolloverSettings(enabled: true, cap: 10000);
      final restored = RolloverSettings.fromJson(s.toJson());
      expect(restored.enabled, isTrue);
      expect(restored.cap, 10000);
    });

    test('未設定キーはデフォルト値で復元される', () {
      final restored = RolloverSettings.fromJson(const {});
      expect(restored.enabled, isFalse);
      expect(restored.cap, isNull);
    });
  });
}
