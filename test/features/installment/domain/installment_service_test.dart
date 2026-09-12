import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/installment/domain/installment_service.dart';
import 'package:kozuchi/features/installment/domain/models/installment_plan.dart';
import 'package:kozuchi/features/installment/domain/models/subscription.dart';

void main() {
  InstallmentPlan plan({
    String id = 'p1',
    int totalAmount = 120000,
    int installmentCount = 12,
    int paidCount = 0,
    DateTime? startDate,
    bool isActive = true,
  }) =>
      InstallmentPlan(
        id: id,
        purpose: '冷蔵庫',
        category: '家電',
        totalAmount: totalAmount,
        installmentCount: installmentCount,
        startDate: startDate ?? DateTime(2026, 1, 15),
        paidCount: paidCount,
        isActive: isActive,
      );

  Subscription sub({
    String id = 's1',
    int amount = 1200,
    int billingDay = 20,
    bool isActive = true,
  }) =>
      Subscription(
        id: id,
        purpose: '動画',
        category: '趣味',
        amount: amount,
        billingDay: billingDay,
        startDate: DateTime(2026, 1, 1),
        isActive: isActive,
      );

  group('monthlyAmount', () {
    test('割り切れる場合はそのまま', () {
      expect(InstallmentService.monthlyAmount(120000, 12), 10000);
    });

    test('端数は切り上げる', () {
      expect(InstallmentService.monthlyAmount(100000, 12), 8334);
    });

    test('総額0は0', () {
      expect(InstallmentService.monthlyAmount(0, 12), 0);
    });

    test('負の総額はArgumentError', () {
      expect(() => InstallmentService.monthlyAmount(-1, 12),
          throwsA(isA<ArgumentError>()));
    });

    test('0回はArgumentError', () {
      expect(() => InstallmentService.monthlyAmount(1000, 0),
          throwsA(isA<ArgumentError>()));
    });
  });

  group('残債計算', () {
    test('未返済なら総額が残債', () {
      expect(InstallmentService.remainingAmount(plan()), 120000);
    });

    test('返済が進むと残債が減る', () {
      expect(InstallmentService.remainingAmount(plan(paidCount: 3)), 90000);
    });

    test('完済後の残債は0（負にならない）', () {
      expect(InstallmentService.remainingAmount(plan(paidCount: 20)), 0);
    });

    test('返済済み額を算出する', () {
      expect(InstallmentService.paidAmount(plan(paidCount: 3)), 30000);
    });
  });

  group('dateInMonth', () {
    test('通常の日付', () {
      expect(InstallmentService.dateInMonth(2026, 5, 10), DateTime(2026, 5, 10));
    });

    test('月末を超える日は月末に丸める', () {
      expect(InstallmentService.dateInMonth(2026, 2, 31), DateTime(2026, 2, 28));
    });

    test('月の桁溢れを正規化する', () {
      expect(InstallmentService.dateInMonth(2026, 13, 5), DateTime(2027, 1, 5));
    });
  });

  group('nextPaymentDate', () {
    test('未返済なら初回支払日', () {
      expect(InstallmentService.nextPaymentDate(plan()), DateTime(2026, 1, 15));
    });

    test('返済回数ぶん進んだ月の同日', () {
      expect(
        InstallmentService.nextPaymentDate(plan(paidCount: 2)),
        DateTime(2026, 3, 15),
      );
    });

    test('年を跨ぐ', () {
      expect(
        InstallmentService.nextPaymentDate(
          plan(startDate: DateTime(2026, 11, 15), paidCount: 3),
        ),
        DateTime(2027, 2, 15),
      );
    });

    test('完済ならnull', () {
      expect(InstallmentService.nextPaymentDate(plan(paidCount: 12)), isNull);
    });
  });

  group('nextBillingDate', () {
    test('当月の請求日が未来なら当月', () {
      expect(
        InstallmentService.nextBillingDate(sub(billingDay: 20),
            from: DateTime(2026, 9, 12)),
        DateTime(2026, 9, 20),
      );
    });

    test('当月の請求日が過ぎていれば翌月', () {
      expect(
        InstallmentService.nextBillingDate(sub(billingDay: 5),
            from: DateTime(2026, 9, 12)),
        DateTime(2026, 10, 5),
      );
    });

    test('基準日当日は当日を返す', () {
      expect(
        InstallmentService.nextBillingDate(sub(billingDay: 12),
            from: DateTime(2026, 9, 12)),
        DateTime(2026, 9, 12),
      );
    });

    test('31日の請求日は月末に丸める', () {
      expect(
        InstallmentService.nextBillingDate(sub(billingDay: 31),
            from: DateTime(2026, 2, 1)),
        DateTime(2026, 2, 28),
      );
    });
  });

  group('集計', () {
    test('月額合計は有効なサブスクのみ', () {
      final subs = [
        sub(id: 'a', amount: 1000),
        sub(id: 'b', amount: 2000),
        sub(id: 'c', amount: 500, isActive: false),
      ];
      expect(InstallmentService.subscriptionMonthlyTotal(subs), 3000);
      expect(InstallmentService.subscriptionYearlyTotal(subs), 36000);
    });

    test('分割払いの月額合計は有効かつ未完済のみ', () {
      final plans = [
        plan(id: 'a', totalAmount: 12000, installmentCount: 12),
        plan(id: 'b', totalAmount: 12000, installmentCount: 12, paidCount: 12),
        plan(id: 'c', totalAmount: 6000, installmentCount: 6, isActive: false),
      ];
      expect(InstallmentService.totalMonthlyInstallmentBurden(plans), 1000);
    });

    test('総残債は有効なプランのみ', () {
      final plans = [
        plan(id: 'a', totalAmount: 12000, installmentCount: 12, paidCount: 6),
        plan(id: 'b', isActive: false),
      ];
      expect(InstallmentService.totalRemainingAmount(plans), 6000);
    });

    test('毎月の固定費は分割＋サブスク', () {
      final total = InstallmentService.totalMonthlyFixedCost(
        plans: [plan(id: 'a', totalAmount: 12000, installmentCount: 12)],
        subscriptions: [sub(amount: 1000)],
      );
      expect(total, 2000);
    });
  });

  group('upcomingBillings', () {
    final from = DateTime(2026, 9, 12);

    test('7日以内の支払い予定を日付順で返す', () {
      final items = InstallmentService.upcomingBillings(
        plans: [
          plan(id: 'p1', startDate: DateTime(2026, 9, 15)),
        ],
        subscriptions: [sub(id: 's1', billingDay: 13, amount: 800)],
        from: from,
      );
      expect(items.map((e) => e.id).toList(), ['s1', 'p1']);
      expect(items.first.isSubscription, isTrue);
      expect(items.last.isSubscription, isFalse);
      expect(items.last.amount, 10000);
    });

    test('窓外の支払いは含めない', () {
      final items = InstallmentService.upcomingBillings(
        plans: [plan(id: 'p1', startDate: DateTime(2026, 10, 1))],
        subscriptions: [sub(id: 's1', billingDay: 25)],
        from: from,
      );
      expect(items, isEmpty);
    });

    test('無効なもの・完済済みは対象外', () {
      final items = InstallmentService.upcomingBillings(
        plans: [
          plan(id: 'p1', startDate: DateTime(2026, 9, 14), isActive: false),
          plan(
            id: 'p2',
            startDate: DateTime(2026, 9, 14),
            paidCount: 12,
            installmentCount: 12,
          ),
        ],
        subscriptions: [sub(id: 's1', billingDay: 14, isActive: false)],
        from: from,
      );
      expect(items, isEmpty);
    });

    test('同日ならid昇順', () {
      final items = InstallmentService.upcomingBillings(
        plans: [plan(id: 'pz', startDate: DateTime(2026, 9, 14))],
        subscriptions: [sub(id: 'sa', billingDay: 14)],
        from: from,
      );
      expect(items.map((e) => e.id).toList(), ['pz', 'sa']);
    });

    test('窓の最終日は含む', () {
      final items = InstallmentService.upcomingBillings(
        plans: [plan(id: 'p1', startDate: DateTime(2026, 9, 19))],
        subscriptions: const [],
        withinDays: 7,
        from: from,
      );
      expect(items.length, 1);
    });
  });
}
