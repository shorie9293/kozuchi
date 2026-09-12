import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/features/installment/data/installment_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const repository = InstallmentRepository();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('InstallmentRepository 分割払い', () {
    test('未保存時は空リスト', () async {
      expect(await repository.loadPlans(), isEmpty);
    });

    test('追加したプランを読み出せる', () async {
      await repository.addPlan(
        purpose: '冷蔵庫',
        category: '家電',
        totalAmount: 120000,
        installmentCount: 12,
        startDate: DateTime(2026, 1, 15),
        id: 'p1',
      );
      final plans = await repository.loadPlans();
      expect(plans.single.id, 'p1');
      expect(plans.single.purpose, '冷蔵庫');
      expect(plans.single.totalAmount, 120000);
      expect(plans.single.paidCount, 0);
    });

    test('名称の前後空白は除去される', () async {
      await repository.addPlan(
        purpose: '  冷蔵庫  ',
        category: ' 家電 ',
        totalAmount: 1000,
        installmentCount: 2,
        startDate: DateTime(2026, 1, 1),
        id: 'p1',
      );
      final plan = (await repository.loadPlans()).single;
      expect(plan.purpose, '冷蔵庫');
      expect(plan.category, '家電');
    });

    test('名称が空白のみならArgumentError', () async {
      expect(
        () => repository.addPlan(
          purpose: '   ',
          category: '家電',
          totalAmount: 1000,
          installmentCount: 2,
          startDate: DateTime(2026, 1, 1),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('総額が負ならArgumentError', () async {
      expect(
        () => repository.addPlan(
          purpose: '冷蔵庫',
          category: '家電',
          totalAmount: -1,
          installmentCount: 2,
          startDate: DateTime(2026, 1, 1),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('分割回数が0以下ならArgumentError', () async {
      expect(
        () => repository.addPlan(
          purpose: '冷蔵庫',
          category: '家電',
          totalAmount: 1000,
          installmentCount: 0,
          startDate: DateTime(2026, 1, 1),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('返済回数を進められる', () async {
      await repository.addPlan(
        purpose: '冷蔵庫',
        category: '家電',
        totalAmount: 1200,
        installmentCount: 3,
        startDate: DateTime(2026, 1, 1),
        id: 'p1',
      );
      await repository.incrementPaid('p1');
      final plans = await repository.incrementPaid('p1');
      expect(plans.single.paidCount, 2);
    });

    test('完済後は返済回数が増えない', () async {
      await repository.addPlan(
        purpose: '冷蔵庫',
        category: '家電',
        totalAmount: 100,
        installmentCount: 1,
        startDate: DateTime(2026, 1, 1),
        id: 'p1',
      );
      await repository.incrementPaid('p1');
      final plans = await repository.incrementPaid('p1');
      expect(plans.single.paidCount, 1);
    });

    test('有効/無効を切り替えられる', () async {
      await repository.addPlan(
        purpose: '冷蔵庫',
        category: '家電',
        totalAmount: 1200,
        installmentCount: 3,
        startDate: DateTime(2026, 1, 1),
        id: 'p1',
      );
      final plans = await repository.togglePlan('p1');
      expect(plans.single.isActive, isFalse);
    });

    test('削除できる', () async {
      await repository.addPlan(
        purpose: '冷蔵庫',
        category: '家電',
        totalAmount: 1200,
        installmentCount: 3,
        startDate: DateTime(2026, 1, 1),
        id: 'p1',
      );
      final plans = await repository.removePlan('p1');
      expect(plans, isEmpty);
    });

    test('破損JSONは空として扱う', () async {
      SharedPreferences.setMockInitialValues({
        InstallmentRepository.plansKey: '{broken',
      });
      expect(await repository.loadPlans(), isEmpty);
    });
  });

  group('InstallmentRepository サブスク', () {
    test('未保存時は空リスト', () async {
      expect(await repository.loadSubscriptions(), isEmpty);
    });

    test('追加したサブスクを読み出せる', () async {
      await repository.addSubscription(
        purpose: '動画',
        category: '趣味',
        amount: 1200,
        billingDay: 20,
        startDate: DateTime(2026, 1, 1),
        id: 's1',
      );
      final subs = await repository.loadSubscriptions();
      expect(subs.single.id, 's1');
      expect(subs.single.amount, 1200);
      expect(subs.single.billingDay, 20);
    });

    test('月額が負ならArgumentError', () async {
      expect(
        () => repository.addSubscription(
          purpose: '動画',
          category: '趣味',
          amount: -1,
          billingDay: 20,
          startDate: DateTime(2026, 1, 1),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('請求日が範囲外ならArgumentError', () async {
      expect(
        () => repository.addSubscription(
          purpose: '動画',
          category: '趣味',
          amount: 1000,
          billingDay: 32,
          startDate: DateTime(2026, 1, 1),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('有効/無効を切り替えられる', () async {
      await repository.addSubscription(
        purpose: '動画',
        category: '趣味',
        amount: 1200,
        billingDay: 20,
        startDate: DateTime(2026, 1, 1),
        id: 's1',
      );
      final subs = await repository.toggleSubscription('s1');
      expect(subs.single.isActive, isFalse);
    });

    test('削除できる', () async {
      await repository.addSubscription(
        purpose: '動画',
        category: '趣味',
        amount: 1200,
        billingDay: 20,
        startDate: DateTime(2026, 1, 1),
        id: 's1',
      );
      final subs = await repository.removeSubscription('s1');
      expect(subs, isEmpty);
    });

    test('破損JSONは空として扱う', () async {
      SharedPreferences.setMockInitialValues({
        InstallmentRepository.subscriptionsKey: '[]',
      });
      expect(await repository.loadSubscriptions(), isEmpty);
    });
  });
}
