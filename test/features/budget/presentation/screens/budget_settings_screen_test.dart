import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/domain/models/monthly_budget.dart';
import 'package:kozuchi/features/shared/data/budget_repository.dart';
import 'package:kozuchi/features/budget/presentation/screens/budget_settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BudgetRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = const BudgetRepository();
  });

  Widget buildTestWidget({VoidCallback? onSaved}) {
    return MaterialApp(
      home: BudgetSettingsScreen(
        repository: repository,
        onSaved: onSaved,
      ),
    );
  }

  group('BudgetSettingsScreen', () {
    testWidgets('画面タイトルが表示される', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      expect(find.text('月間予算設定'), findsOneWidget);
    });

    testWidgets('現在の年月が表示される', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final currentMonth = MonthlyBudget.currentYearMonth();
      expect(find.textContaining(currentMonth), findsOneWidget);
    });

    testWidgets('予算入力欄が表示される', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('保存ボタンが表示される', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('予算を設定する'), findsOneWidget);
    });

    testWidgets('保存済みの予算がある場合は初期表示される', (tester) async {
      // 事前に予算を保存
      final currentMonth = MonthlyBudget.currentYearMonth();
      await repository.saveBudget(
        MonthlyBudget(yearMonth: currentMonth, amount: 150000),
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // 入力欄に150000が表示されている
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, '150000');
    });

    testWidgets('予算を入力して保存できる', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // 金額を入力
      await tester.enterText(find.byType(TextField), '200000');
      await tester.pumpAndSettle();

      // 保存ボタンをタップ
      await tester.tap(find.text('予算を設定する'));
      await tester.pumpAndSettle();

      // 保存されたことを確認（SnackBar）
      expect(find.textContaining('予算を設定しました'), findsOneWidget);

      // 実際に永続化されているか確認
      final currentMonth = MonthlyBudget.currentYearMonth();
      final saved = await repository.loadBudget(currentMonth);
      expect(saved, isNotNull);
      expect(saved!.amount, 200000);
    });

    testWidgets('空の予算では保存できない（バリデーション）', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // 空文字のまま保存ボタンをタップ
      await tester.tap(find.text('予算を設定する'));
      await tester.pumpAndSettle();

      // エラーメッセージが表示される
      expect(find.text('予算額を入力してください'), findsOneWidget);

      // 保存されていないことを確認
      final currentMonth = MonthlyBudget.currentYearMonth();
      final saved = await repository.loadBudget(currentMonth);
      expect(saved, isNull);
    });

    testWidgets('保存成功時にonSavedコールバックが呼ばれる', (tester) async {
      bool callbackCalled = false;
      await tester.pumpWidget(buildTestWidget(onSaved: () => callbackCalled = true));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '100000');
      await tester.pumpAndSettle();
      await tester.tap(find.text('予算を設定する'));
      await tester.pumpAndSettle();

      expect(callbackCalled, isTrue);
    });
  });
}
