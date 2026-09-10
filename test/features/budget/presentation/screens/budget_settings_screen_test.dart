import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/domain/models/monthly_budget.dart';
import 'package:kozuchi/features/budget/data/rollover_settings_repository.dart';
import 'package:kozuchi/features/shared/data/budget_repository.dart';
import 'package:kozuchi/features/budget/presentation/screens/budget_settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BudgetRepository repository;
  late RolloverSettingsRepository rolloverRepository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = const BudgetRepository();
    rolloverRepository = const RolloverSettingsRepository();
  });

  Widget buildTestWidget({
    VoidCallback? onSaved,
    RolloverSettingsRepository? rollover,
  }) {
    return MaterialApp(
      home: BudgetSettingsScreen(
        repository: repository,
        onSaved: onSaved,
        rolloverRepository: rollover ?? rolloverRepository,
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

  group('BudgetSettingsScreen 予算繰り越し', () {
    testWidgets('繰り越しカードが表示される', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('予算の繰り越し'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('繰り越し無効時は中立メッセージが表示される', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('先月の繰越・超過はありません'), findsOneWidget);
    });

    testWidgets('繰り越し有効時は前月残額がプレビューされる', (tester) async {
      final prevMonth = MonthlyBudget.previousYearMonth();
      await repository.saveBudget(
        MonthlyBudget(yearMonth: prevMonth, amount: 100000),
      );
      await repository.saveMonthlySpending(prevMonth, 60000);
      await rolloverRepository.setEnabled(true);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.textContaining('先月からの繰越: ¥40000'), findsOneWidget);
      expect(find.textContaining('実質予算 ¥40000'), findsOneWidget);
    });

    testWidgets('前月超過時は警告が表示される', (tester) async {
      final prevMonth = MonthlyBudget.previousYearMonth();
      await repository.saveBudget(
        MonthlyBudget(yearMonth: prevMonth, amount: 100000),
      );
      await repository.saveMonthlySpending(prevMonth, 130000);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.textContaining('先月の超過: ¥30000'), findsOneWidget);
    });

    testWidgets('スイッチを切り替えると設定が永続化される', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect((await rolloverRepository.load()).enabled, isTrue);
    });
  });
}
