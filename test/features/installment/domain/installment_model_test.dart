import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/installment/domain/models/installment_plan.dart';
import 'package:kozuchi/features/installment/domain/models/subscription.dart';

void main() {
  group('InstallmentPlan', () {
    InstallmentPlan build({
      int totalAmount = 120000,
      int installmentCount = 12,
      int paidCount = 0,
      DateTime? startDate,
    }) =>
        InstallmentPlan(
          id: 'p1',
          purpose: '冷蔵庫',
          category: '家電',
          totalAmount: totalAmount,
          installmentCount: installmentCount,
          startDate: startDate ?? DateTime(2026, 1, 15),
          paidCount: paidCount,
        );

    test('残り回数を算出する', () {
      expect(build(paidCount: 0).remainingCount, 12);
      expect(build(paidCount: 5).remainingCount, 7);
    });

    test('返済回数が分割回数を超えても残り回数は0', () {
      expect(build(paidCount: 20).remainingCount, 0);
    });

    test('完済判定', () {
      expect(build(paidCount: 11).isCompleted, isFalse);
      expect(build(paidCount: 12).isCompleted, isTrue);
      expect(build(paidCount: 13).isCompleted, isTrue);
    });

    test('進捗率は0.0〜1.0に収まる', () {
      expect(build(paidCount: 0).progress, 0.0);
      expect(build(paidCount: 6).progress, 0.5);
      expect(build(paidCount: 12).progress, 1.0);
      expect(build(paidCount: 20).progress, 1.0);
    });

    test('JSON往復で値が保持される', () {
      final plan = build(paidCount: 3);
      final restored = InstallmentPlan.fromJson(plan.toJson());
      expect(restored.id, 'p1');
      expect(restored.purpose, '冷蔵庫');
      expect(restored.category, '家電');
      expect(restored.totalAmount, 120000);
      expect(restored.installmentCount, 12);
      expect(restored.paidCount, 3);
      expect(restored.startDate, DateTime(2026, 1, 15));
      expect(restored.isActive, isTrue);
    });

    test('idが同一なら等価', () {
      expect(build(paidCount: 1), build(paidCount: 5));
      expect(build().hashCode, build().hashCode);
    });

    test('copyWithで更新できる', () {
      final plan = build();
      final updated = plan.copyWith(paidCount: 4, isActive: false);
      expect(updated.paidCount, 4);
      expect(updated.isActive, isFalse);
      expect(updated.id, plan.id);
      expect(updated.purpose, plan.purpose);
    });

    test('破損JSONは既定値で復元される', () {
      final restored = InstallmentPlan.fromJson(const {});
      expect(restored.id, '');
      expect(restored.totalAmount, 0);
      expect(restored.installmentCount, 1);
      expect(restored.paidCount, 0);
    });
  });

  group('Subscription', () {
    Subscription build({int amount = 1200, bool isActive = true}) => Subscription(
          id: 's1',
          purpose: '動画',
          category: '趣味',
          amount: amount,
          billingDay: 20,
          startDate: DateTime(2026, 1, 1),
          isActive: isActive,
        );

    test('年額は月額×12', () {
      expect(build(amount: 1200).yearlyAmount, 14400);
    });

    test('JSON往復で値が保持される', () {
      final sub = build();
      final restored = Subscription.fromJson(sub.toJson());
      expect(restored.id, 's1');
      expect(restored.amount, 1200);
      expect(restored.billingDay, 20);
      expect(restored.isActive, isTrue);
    });

    test('copyWithで有効/無効を切り替えられる', () {
      expect(build().copyWith(isActive: false).isActive, isFalse);
    });

    test('idが同一なら等価', () {
      expect(build(amount: 100), build(amount: 200));
    });
  });
}
