import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kozuchi/domain/models/monthly_budget.dart';
import 'package:kozuchi/features/budget/data/category_budget_repository.dart';
import 'package:kozuchi/features/budget/presentation/category_budget_app_keys.dart';
import 'package:kozuchi/features/budget/presentation/screens/budget_settings_screen.dart';
import 'package:kozuchi/features/budget/presentation/screens/category_budget_screen.dart';
import 'package:kozuchi/features/category_ledger/data/category_ledger_repository.dart';
import 'package:kozuchi/features/category_ledger/domain/category_ledger.dart';
import 'package:kozuchi/features/category_ledger/presentation/category_ledger_app_keys.dart';
import 'package:kozuchi/features/shared/data/budget_repository.dart';
import 'package:kozuchi/features/trial_quest/presentation/screens/offering_input_screen.dart';
import 'package:kozuchi/domain/models/trial_quest.dart';
import 'package:kozuchi/domain/models/player_model.dart';
import 'package:kozuchi/domain/models/advisor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('配線: budget_settings_screen → カテゴリ管理画面', () {
    testWidgets('導線ボタンでカテゴリ管理画面が開く', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BudgetSettingsScreen(
            repository: const BudgetRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(CategoryLedgerAppKeys.openButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('カテゴリ管理'), findsOneWidget);
      expect(
        find.byKey(CategoryLedgerAppKeys.categoryLedgerScreen),
        findsOneWidget,
      );
    });
  });

  group('配線: offering_input_screen → カテゴリ台帳', () {
    final quest = TrialQuest(
      title: '誰かと食事を共にせよ',
      description: '友人や家族と食事をし、会計を済ませよ',
      suggestedOffering: 3000,
      advisor: Advisor.daikokuten,
    );
    final player = PlayerModel(hp: 100000, exp: 30);

    testWidgets('台帳に追加したカテゴリがチップに表示される', (tester) async {
      final ledgerRepo = InMemoryCategoryLedgerRepository()
        ..stored = CategoryLedger(
          [...CategoryLedger.defaults().categories, 'ペット費'],
        );

      await tester.pumpWidget(
        MaterialApp(
          home: OfferingInputScreen(
            quest: quest,
            player: player,
            categoryLedgerRepository: ledgerRepo,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('ペット費'), findsOneWidget);
      // 既定カテゴリも表示される
      expect(find.textContaining('食費'), findsOneWidget);
    });
  });

  group('配線: category_budget_screen → カテゴリ台帳', () {
    DateTime fixedClock() => DateTime(2026, 9, 15, 12);

    testWidgets('categories 未指定のとき台帳のカテゴリが表示される', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final ledgerRepo = InMemoryCategoryLedgerRepository()
        ..stored = CategoryLedger(['食費', '交通費', 'その他', 'ペット費']);
      final budgetRepo = CategoryBudgetRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: CategoryBudgetScreen(
            repository: budgetRepo,
            spentLoader: (_) async => const {},
            yearMonth: MonthlyBudget.currentYearMonth(),
            clock: fixedClock,
            categoryLedgerRepository: ledgerRepo,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(CategoryBudgetAppKeys.row('ペット費')),
        findsOneWidget,
      );
      expect(
        find.byKey(CategoryBudgetAppKeys.row('食費')),
        findsOneWidget,
      );
    });
  });
}