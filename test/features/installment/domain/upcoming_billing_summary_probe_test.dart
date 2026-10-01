import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/features/installment/data/installment_repository.dart';
import 'package:kozuchi/features/installment/domain/models/installment_plan.dart';
import 'package:kozuchi/features/installment/domain/models/subscription.dart';
import 'package:kozuchi/features/installment/domain/upcoming_billing_summary.dart';
import 'package:kozuchi/features/installment/presentation/installment_app_keys.dart';
import 'package:kozuchi/features/installment/presentation/screens/upcoming_billing_screen.dart';

/// 親探針: 子の試練が撃っていない「合成不変条件」を検証する。
///
/// - 決定論のため from / now は必ず固定日付（2026/10/2）を注入する。
/// - 実装ファイルは変更せず、仕様としての不変条件のみを撃つ。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final from = DateTime(2026, 10, 2);

  InstallmentPlan plan(
    String id, {
    required DateTime startDate,
    int totalAmount = 12000,
    int installmentCount = 12,
  }) =>
      InstallmentPlan(
        id: id,
        purpose: 'plan-$id',
        category: 'test',
        totalAmount: totalAmount,
        installmentCount: installmentCount,
        startDate: startDate,
        paidCount: 0,
        isActive: true,
      );

  Subscription sub(
    String id, {
    required int billingDay,
    int amount = 1000,
  }) =>
      Subscription(
        id: id,
        purpose: 'sub-$id',
        category: 'test',
        amount: amount,
        billingDay: billingDay,
        startDate: DateTime(2026, 1, 1),
      );

  group('親探針: UpcomingBillingSummaryService 合成不変条件', () {
    test('不変条件1: groups は日付昇順に並ぶ', () {
      final summary = UpcomingBillingSummaryService.build(
        plans: [
          plan('p20', startDate: DateTime(2026, 10, 20)),
        ],
        subscriptions: [
          sub('s12', billingDay: 12),
          sub('s5', billingDay: 5),
        ],
        withinDays: 30,
        from: from,
      );

      expect(summary.groups.map((g) => g.date).toList(), [
        DateTime(2026, 10, 5),
        DateTime(2026, 10, 12),
        DateTime(2026, 10, 20),
      ]);
      expect(summary.nextDate, DateTime(2026, 10, 5));
    });

    test('不変条件2: totalAmount / count は全グループの合計と整合する', () {
      final summary = UpcomingBillingSummaryService.build(
        plans: [
          plan('p5', startDate: DateTime(2026, 10, 5), totalAmount: 6000, installmentCount: 12), // 月500
          plan('p20', startDate: DateTime(2026, 10, 20), totalAmount: 12000, installmentCount: 12), // 月1000
        ],
        subscriptions: [
          sub('s5', billingDay: 5, amount: 300),
          sub('s20', billingDay: 20, amount: 700),
        ],
        withinDays: 30,
        from: from,
      );

      final groupSum = summary.groups.fold<int>(0, (s, g) => s + g.totalAmount);
      final groupCount = summary.groups.fold<int>(0, (s, g) => s + g.count);

      expect(summary.totalAmount, groupSum);
      expect(summary.count, groupCount);
      // 検算: 10/5 = 500+300, 10/20 = 1000+700
      expect(summary.totalAmount, 2500);
      expect(summary.count, 4);
    });

    test('不変条件3: 境界包含 — withinDays=7 で 10/9 は含まれ 10/10 は含まれない', () {
      final summary = UpcomingBillingSummaryService.build(
        plans: const [],
        subscriptions: [
          sub('s9', billingDay: 9, amount: 900),
          sub('s10', billingDay: 10, amount: 1000),
        ],
        withinDays: 7,
        from: from,
      );

      final ids = summary.groups
          .expand((g) => g.billings.map((b) => b.id))
          .toList();
      expect(ids, contains('s9')); // from + 7日 = 10/9 は含まれる
      expect(ids, isNot(contains('s10'))); // from + 8日 = 10/10 は除外
      expect(summary.count, 1);
      expect(summary.totalAmount, 900);
    });

    test('不変条件4: 同日グループ内の billings は id 昇順', () {
      final summary = UpcomingBillingSummaryService.build(
        plans: [
          plan('b', startDate: DateTime(2026, 10, 5)),
          plan('a', startDate: DateTime(2026, 10, 5)),
        ],
        subscriptions: const [],
        withinDays: 30,
        from: from,
      );

      final group = summary.groups.single;
      expect(group.date, DateTime(2026, 10, 5));
      expect(group.billings.map((b) => b.id).toList(), ['a', 'b']);
    });

    test('不変条件5: 非破壊 — build 前後で入力リストの長さ・内容が不変', () {
      final plans = [
        plan('p20', startDate: DateTime(2026, 10, 20)),
        plan('p5', startDate: DateTime(2026, 10, 5)),
      ];
      final subs = [
        sub('s12', billingDay: 12),
      ];
      final plansSnapshot = plans.map((p) => p.id).toList();
      final subsSnapshot = subs.map((s) => s.id).toList();

      UpcomingBillingSummaryService.build(
        plans: plans,
        subscriptions: subs,
        withinDays: 30,
        from: from,
      );

      expect(plans.length, plansSnapshot.length);
      expect(plans.map((p) => p.id).toList(), plansSnapshot);
      expect(subs.length, subsSnapshot.length);
      expect(subs.map((s) => s.id).toList(), subsSnapshot);
    });
  });

  group('親探針: UpcomingBillingScreen との合成', () {
    final now = DateTime(2026, 10, 2);
    const repository = InstallmentRepository();

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('不変条件6: 異なる2日のサブスク → 日付グループKeyが2つ現れ合計が一致する', (tester) async {
      await repository.addSubscription(
        purpose: '動画サブスク',
        category: '趣味',
        amount: 500,
        billingDay: 5,
        startDate: DateTime(2026, 1, 1),
        id: 's5',
      );
      await repository.addSubscription(
        purpose: '音楽サブスク',
        category: '趣味',
        amount: 700,
        billingDay: 20,
        startDate: DateTime(2026, 1, 1),
        id: 's20',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: UpcomingBillingScreen(
            repository: repository,
            now: now,
            initialWithinDays: 30,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 2つの日付グループKeyが現れる（10/5 と 10/20）
      expect(find.byKey(InstallmentAppKeys.upcomingDateGroup('20261005')), findsOneWidget);
      expect(find.byKey(InstallmentAppKeys.upcomingDateGroup('20261020')), findsOneWidget);
      // 日付ヘッダも昇順に2つ
      expect(find.text('10月5日'), findsOneWidget);
      expect(find.text('10月20日'), findsOneWidget);
      // 合計 = 500 + 700 = 1200
      expect(
        tester.widget<Text>(find.byKey(InstallmentAppKeys.upcomingTotal)).data,
        '¥1,200',
      );
      expect(find.text('件数 2件'), findsOneWidget);
    });
  });
}