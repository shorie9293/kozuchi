import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/features/installment/data/installment_repository.dart';
import 'package:kozuchi/features/installment/presentation/installment_app_keys.dart';
import 'package:kozuchi/features/installment/presentation/screens/installment_screen.dart';
import 'package:kozuchi/features/installment/presentation/screens/subscription_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const repository = InstallmentRepository();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpInstallment(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: InstallmentScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpSubscription(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SubscriptionScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
  }

  group('InstallmentScreen', () {
    testWidgets('プランが無いときは空状態を表示する', (tester) async {
      await pumpInstallment(tester);
      expect(find.byKey(InstallmentAppKeys.installmentScreen), findsOneWidget);
      expect(find.byKey(InstallmentAppKeys.installmentEmpty), findsOneWidget);
    });

    testWidgets('ダイアログから分割払いを追加できる', (tester) async {
      await pumpInstallment(tester);
      await tester.tap(find.byKey(InstallmentAppKeys.installmentAddButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(InstallmentAppKeys.purposeField), '冷蔵庫');
      await tester.enterText(find.byKey(InstallmentAppKeys.amountField), '120000');
      await tester.enterText(find.byKey(InstallmentAppKeys.countField), '12');
      await tester.tap(find.byKey(InstallmentAppKeys.dialogSaveButton));
      await tester.pumpAndSettle();

      expect(find.text('冷蔵庫'), findsOneWidget);
      expect(find.byKey(InstallmentAppKeys.installmentEmpty), findsNothing);
      expect(find.textContaining('残債 ¥120,000'), findsOneWidget);
    });

    testWidgets('空欄では保存せずエラーを表示する', (tester) async {
      await pumpInstallment(tester);
      await tester.tap(find.byKey(InstallmentAppKeys.installmentAddButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(InstallmentAppKeys.dialogSaveButton));
      await tester.pumpAndSettle();

      expect(find.text('名称と総額を正しく入力してください'), findsOneWidget);
      expect((await repository.loadPlans()), isEmpty);
    });

    testWidgets('「1回返済」で進捗が更新される', (tester) async {
      await repository.addPlan(
        purpose: '冷蔵庫',
        category: '家電',
        totalAmount: 1200,
        installmentCount: 3,
        startDate: DateTime(2026, 1, 1),
        id: 'p1',
      );
      await pumpInstallment(tester);

      expect(find.text('0/3 回 返済済み'), findsOneWidget);
      await tester.tap(find.byKey(InstallmentAppKeys.installmentPayButton('p1')));
      await tester.pumpAndSettle();

      expect(find.text('1/3 回 返済済み'), findsOneWidget);
    });

    testWidgets('削除ボタンでプランが消える', (tester) async {
      await repository.addPlan(
        purpose: '冷蔵庫',
        category: '家電',
        totalAmount: 1200,
        installmentCount: 3,
        startDate: DateTime(2026, 1, 1),
        id: 'p1',
      );
      await pumpInstallment(tester);

      await tester.tap(
        find.byKey(InstallmentAppKeys.installmentDeleteButton('p1')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(InstallmentAppKeys.installmentEmpty), findsOneWidget);
    });
  });

  group('SubscriptionScreen', () {
    testWidgets('サブスクが無いときは空状態を表示する', (tester) async {
      await pumpSubscription(tester);
      expect(find.byKey(InstallmentAppKeys.subscriptionScreen), findsOneWidget);
      expect(find.byKey(InstallmentAppKeys.subscriptionEmpty), findsOneWidget);
    });

    testWidgets('ダイアログからサブスクを追加し月額合計に反映する', (tester) async {
      await pumpSubscription(tester);
      await tester.tap(find.byKey(InstallmentAppKeys.subscriptionAddButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(InstallmentAppKeys.purposeField), '動画');
      await tester.enterText(find.byKey(InstallmentAppKeys.amountField), '1200');
      await tester.enterText(find.byKey(InstallmentAppKeys.countField), '20');
      await tester.tap(find.byKey(InstallmentAppKeys.dialogSaveButton));
      await tester.pumpAndSettle();

      expect(find.text('動画'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(InstallmentAppKeys.subscriptionMonthlyTotal))
            .data,
        '¥1,200',
      );
    });

    testWidgets('トグルで無効化すると月額合計から外れる', (tester) async {
      await repository.addSubscription(
        purpose: '動画',
        category: '趣味',
        amount: 1200,
        billingDay: 20,
        startDate: DateTime(2026, 1, 1),
        id: 's1',
      );
      await pumpSubscription(tester);

      await tester.tap(find.byKey(InstallmentAppKeys.subscriptionToggle('s1')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(find.byKey(InstallmentAppKeys.subscriptionMonthlyTotal))
            .data,
        '¥0',
      );
    });

    testWidgets('請求日が不正ならエラーを表示する', (tester) async {
      await pumpSubscription(tester);
      await tester.tap(find.byKey(InstallmentAppKeys.subscriptionAddButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(InstallmentAppKeys.purposeField), '動画');
      await tester.enterText(find.byKey(InstallmentAppKeys.amountField), '1200');
      await tester.enterText(find.byKey(InstallmentAppKeys.countField), '40');
      await tester.tap(find.byKey(InstallmentAppKeys.dialogSaveButton));
      await tester.pumpAndSettle();

      expect(find.text('請求日は1〜31で入力してください'), findsOneWidget);
      expect(await repository.loadSubscriptions(), isEmpty);
    });
  });
}
