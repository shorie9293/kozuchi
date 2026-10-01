import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/installment/domain/models/installment_plan.dart';
import 'package:kozuchi/features/installment/domain/models/subscription.dart';
import 'package:kozuchi/features/installment/domain/upcoming_billing_summary.dart';

void main() {
  // 決定論的テスト: DateTime.now() 依存を避けるため from を固定注入する。
  final from = DateTime(2026, 10, 2);

  InstallmentPlan plan(
    String id, {
    required DateTime startDate,
    int totalAmount = 12000,
    int installmentCount = 12,
    int paidCount = 0,
    bool isActive = true,
  }) =>
      InstallmentPlan(
        id: id,
        purpose: 'plan-$id',
        category: 'test',
        totalAmount: totalAmount,
        installmentCount: installmentCount,
        startDate: startDate,
        paidCount: paidCount,
        isActive: isActive,
      );

  Subscription sub(
    String id, {
    required DateTime startDate,
    int billingDay = 2,
    int amount = 1000,
  }) =>
      Subscription(
        id: id,
        purpose: 'sub-$id',
        category: 'test',
        amount: amount,
        billingDay: billingDay,
        startDate: startDate,
      );

  group('UpcomingBillingSummaryService.build', () {
    test('空の plans/subscriptions → 空サマリー', () {
      final summary = UpcomingBillingSummaryService.build(
        plans: const [],
        subscriptions: const [],
        withinDays: 30,
        from: from,
      );

      expect(summary.isEmpty, isTrue);
      expect(summary.count, 0);
      expect(summary.totalAmount, 0);
      expect(summary.nextDate, isNull);
      expect(summary.groups, isEmpty);
    });

    test('複数プランが同日 → 1グループに集約され count/totalAmount が正しい', () {
      final summary = UpcomingBillingSummaryService.build(
        plans: [
          plan('p1', startDate: DateTime(2026, 10, 5), totalAmount: 10000, installmentCount: 10), // 月1000
          plan('p2', startDate: DateTime(2026, 10, 5), totalAmount: 1200, installmentCount: 12), // 月100
        ],
        subscriptions: const [],
        withinDays: 30,
        from: from,
      );

      expect(summary.groups.length, 1);
      final group = summary.groups.single;
      expect(group.date, DateTime(2026, 10, 5));
      expect(group.count, 2);
      expect(group.totalAmount, 1100);
      expect(group.billings.map((b) => b.id).toList(), ['p1', 'p2']);
      expect(summary.count, 2);
      expect(summary.totalAmount, 1100);
    });

    test('異なる日のプラン・サブスク混在 → グループ date 昇順', () {
      final summary = UpcomingBillingSummaryService.build(
        plans: [
          plan('p1', startDate: DateTime(2026, 10, 10), totalAmount: 12000, installmentCount: 12), // 月1000
        ],
        subscriptions: [
          sub('s1', startDate: DateTime(2026, 1, 1), billingDay: 3, amount: 500),
          sub('s2', startDate: DateTime(2026, 1, 1), billingDay: 3, amount: 700),
        ],
        withinDays: 30,
        from: from,
      );

      // from=10/2 → 10/3 にサブスク2件、10/10 にプラン1件
      expect(summary.groups.length, 2);
      expect(summary.groups[0].date, DateTime(2026, 10, 3));
      expect(summary.groups[0].count, 2);
      expect(summary.groups[0].billings.map((b) => b.id).toList(), ['s1', 's2']);
      expect(summary.groups[1].date, DateTime(2026, 10, 10));
      expect(summary.groups[1].billings.map((b) => b.id).toList(), ['p1']);
      expect(summary.count, 3);
      expect(summary.totalAmount, 2200);
    });

    test('グループ内 billings は id 昇順（入力順とは逆に投入しても並ぶ）', () {
      final summary = UpcomingBillingSummaryService.build(
        plans: [
          plan('pB', startDate: DateTime(2026, 10, 5), totalAmount: 1200, installmentCount: 12),
          plan('pA', startDate: DateTime(2026, 10, 5), totalAmount: 1200, installmentCount: 12),
        ],
        subscriptions: const [],
        withinDays: 30,
        from: from,
      );

      expect(summary.groups.single.billings.map((b) => b.id).toList(), ['pA', 'pB']);
    });

    test('withinDays=0 → 当日のみ対象', () {
      final summary = UpcomingBillingSummaryService.build(
        plans: [
          plan('pToday', startDate: DateTime(2026, 10, 2), totalAmount: 12000, installmentCount: 12),
          plan('pTomorrow', startDate: DateTime(2026, 10, 3), totalAmount: 12000, installmentCount: 12),
        ],
        subscriptions: const [],
        withinDays: 0,
        from: from,
      );

      expect(summary.groups.length, 1);
      expect(summary.groups.single.date, DateTime(2026, 10, 2));
      expect(summary.groups.single.billings.single.id, 'pToday');
      expect(summary.count, 1);
    });

    test('withinDays 負値 → 0 として扱い例外にならない', () {
      final summary = UpcomingBillingSummaryService.build(
        plans: [
          plan('pToday', startDate: DateTime(2026, 10, 2), totalAmount: 12000, installmentCount: 12),
          plan('pLater', startDate: DateTime(2026, 10, 20), totalAmount: 12000, installmentCount: 12),
        ],
        subscriptions: const [],
        withinDays: -5,
        from: from,
      );

      expect(summary.withinDays, 0);
      expect(summary.groups.length, 1);
      expect(summary.groups.single.date, DateTime(2026, 10, 2));
      expect(summary.count, 1);
    });

    test('サブスク由来は isSubscription=true、分割払い由来は false', () {
      final summary = UpcomingBillingSummaryService.build(
        plans: [
          plan('p1', startDate: DateTime(2026, 10, 5), totalAmount: 1200, installmentCount: 12),
        ],
        subscriptions: [
          sub('s1', startDate: DateTime(2026, 1, 1), billingDay: 5, amount: 980),
        ],
        withinDays: 30,
        from: from,
      );

      final billings = summary.groups.single.billings;
      expect(billings.length, 2);
      expect(billings.firstWhere((b) => b.id == 'p1').isSubscription, isFalse);
      expect(billings.firstWhere((b) => b.id == 's1').isSubscription, isTrue);
    });

    test('totalAmount は全グループ totalAmount の合計と一致', () {
      final summary = UpcomingBillingSummaryService.build(
        plans: [
          plan('p1', startDate: DateTime(2026, 10, 5), totalAmount: 3000, installmentCount: 3), // 月1000
          plan('p2', startDate: DateTime(2026, 10, 15), totalAmount: 5000, installmentCount: 5), // 月1000
        ],
        subscriptions: [
          sub('s1', startDate: DateTime(2026, 1, 1), billingDay: 8, amount: 1500),
        ],
        withinDays: 30,
        from: from,
      );

      final groupSum = summary.groups.fold<int>(0, (s, g) => s + g.totalAmount);
      expect(groupSum, 3500);
      expect(summary.totalAmount, groupSum);
      expect(summary.count, 3);
    });

    test('nextDate は直近グループの日付、groups 内 date は 00:00 正規化', () {
      final summary = UpcomingBillingSummaryService.build(
        plans: [
          plan('p1', startDate: DateTime(2026, 10, 20), totalAmount: 12000, installmentCount: 12),
        ],
        subscriptions: [
          sub('s1', startDate: DateTime(2026, 1, 1), billingDay: 10, amount: 500),
        ],
        withinDays: 30,
        from: from,
      );

      expect(summary.nextDate, DateTime(2026, 10, 10));
      for (final group in summary.groups) {
        expect(group.date.hour, 0);
        expect(group.date.minute, 0);
        expect(group.date.second, 0);
      }
    });

    test('非活性プラン・完済プランは集計対象外', () {
      final summary = UpcomingBillingSummaryService.build(
        plans: [
          plan('pActive', startDate: DateTime(2026, 10, 5), totalAmount: 1200, installmentCount: 12),
          plan('pInactive',
            startDate: DateTime(2026, 10, 5),
            totalAmount: 1200,
            installmentCount: 12,
            isActive: false,
          ),
          plan('pCompleted',
            startDate: DateTime(2026, 10, 5),
            totalAmount: 1200,
            installmentCount: 12,
            paidCount: 12,
          ),
        ],
        subscriptions: const [],
        withinDays: 30,
        from: from,
      );

      expect(summary.count, 1);
      expect(summary.groups.single.billings.single.id, 'pActive');
    });

    test('同一 from に対する build は決定的（2回呼んで同一結果）', () {
      final plans = [
        plan('p1', startDate: DateTime(2026, 10, 5), totalAmount: 1200, installmentCount: 12),
        plan('p2', startDate: DateTime(2026, 10, 8), totalAmount: 2400, installmentCount: 12),
      ];
      final subs = [
        sub('s1', startDate: DateTime(2026, 1, 1), billingDay: 6, amount: 300),
      ];

      final a = UpcomingBillingSummaryService.build(
        plans: plans,
        subscriptions: subs,
        withinDays: 30,
        from: from,
      );
      final b = UpcomingBillingSummaryService.build(
        plans: plans,
        subscriptions: subs,
        withinDays: 30,
        from: from,
      );

      expect(a.count, b.count);
      expect(a.totalAmount, b.totalAmount);
      expect(a.nextDate, b.nextDate);
      expect(
        a.groups.map((g) => g.date).toList(),
        b.groups.map((g) => g.date).toList(),
      );
      // 非破壊: 入力リストがソート等で書き換えられていないこと
      expect(plans.length, 2);
      expect(subs.length, 1);
    });
  });
}
