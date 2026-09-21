import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/features/budget/data/category_budget_repository.dart';
import 'package:kozuchi/features/budget/presentation/category_budget_app_keys.dart';
import 'package:kozuchi/features/budget/presentation/screens/budget_settings_screen.dart';
import 'package:kozuchi/features/budget/presentation/screens/category_budget_screen.dart';
import 'package:kozuchi/features/shared/data/budget_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testCategories = ['食費', '交通費', '娯楽', 'その他'];
  const testMonth = '2026-09';
  DateTime fixedClock() => DateTime(2026, 9, 15, 12);

  late CategoryBudgetRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = const CategoryBudgetRepository();
  });

  /// 画面を描画するヘルパー（pumpAndSettle を避け pump で進める）
  Future<void> pumpScreen(
    WidgetTester tester, {
    Map<String, int> spent = const {},
    String? yearMonth,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CategoryBudgetScreen(
          repository: repository,
          spentLoader: (_) async => spent,
          categories: testCategories,
          yearMonth: yearMonth ?? testMonth,
          clock: fixedClock,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('CategoryBudgetScreen 一覧表示', () {
    testWidgets('カテゴリ行が全件表示される', (tester) async {
      await pumpScreen(tester, spent: const {'食費': 10000});

      for (final category in testCategories) {
        expect(find.byKey(CategoryBudgetAppKeys.row(category)), findsOneWidget);
      }
    });

    testWidgets('key row(category) で見つかる', (tester) async {
      await pumpScreen(tester);

      final foodRow =
          tester.widget(find.byKey(CategoryBudgetAppKeys.row('食費')));
      expect(foodRow, isNotNull);
    });

    testWidgets('予算未設定のカテゴリは「未設定」と表示される', (tester) async {
      await pumpScreen(tester);

      final stateText =
          tester.widget<Text>(find.byKey(CategoryBudgetAppKeys.state('食費')));
      expect(stateText.data, '未設定');
    });

    testWidgets('超過カテゴリが先頭に来る', (tester) async {
      await repository.saveBudget(testMonth, '食費', 10000);
      await repository.saveBudget(testMonth, '交通費', 20000);
      await pumpScreen(
        tester,
        spent: const {'食費': 15000, '交通費': 5000},
      );

      // 超過した食費が先頭のカテゴリ行として表示される
      final rowFinder = find.byKey(CategoryBudgetAppKeys.row('食費'));
      expect(rowFinder, findsOneWidget);
      final foodRowRect = tester.getRect(rowFinder);
      final transportRowRect =
          tester.getRect(find.byKey(CategoryBudgetAppKeys.row('交通費')));
      expect(foodRowRect.top, lessThan(transportRowRect.top));
      // 超過ラベルが付いていること
      final stateText =
          tester.widget<Text>(find.byKey(CategoryBudgetAppKeys.state('食費')));
      expect(stateText.data, '超過');
    });

    testWidgets('警告（予算の80%以上）のカテゴリが表示される', (tester) async {
      await repository.saveBudget(testMonth, '交通費', 10000);
      await pumpScreen(tester, spent: const {'交通費': 8000});

      final stateText =
          tester.widget<Text>(find.byKey(CategoryBudgetAppKeys.state('交通費')));
      expect(stateText.data, 'まもなく超過');
    });

    testWidgets('サマリーの警告・超過件数が正しい', (tester) async {
      await repository.saveBudget(testMonth, '食費', 10000);
      await repository.saveBudget(testMonth, '交通費', 10000);
      await pumpScreen(
        tester,
        spent: const {'食費': 12000, '交通費': 9000},
      );

      final summaryText = tester.widget<Text>(
        find.descendant(
          of: find.byKey(CategoryBudgetAppKeys.categoryBudget_summary),
          matching: find.byType(Text),
        ).first,
      );
      expect(summaryText.data, '警告 1件 ・ 超過 1件');
    });

    testWidgets('支出ローダでエラー時も一覧は表示される（握りつぶし）', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CategoryBudgetScreen(
            repository: repository,
            spentLoader: (_) async => throw StateError('boom'),
            categories: testCategories,
            yearMonth: testMonth,
            clock: fixedClock,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(CategoryBudgetAppKeys.row('食費')),
        findsOneWidget,
      );
    });
  });

  group('CategoryBudgetScreen 編集ダイアログ', () {
    testWidgets('行タップでダイアログが開く', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.byKey(CategoryBudgetAppKeys.row('食費')));
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(CategoryBudgetAppKeys.categoryBudget_editDialog),
        findsOneWidget,
      );
    });

    testWidgets('金額入力して保存でリポジトリに保存される', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.byKey(CategoryBudgetAppKeys.row('食費')));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.enterText(
        find.byKey(CategoryBudgetAppKeys.categoryBudget_amountField),
        '30000',
      );
      await tester.tap(
        find.byKey(CategoryBudgetAppKeys.categoryBudget_saveButton),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final budgets = await repository.loadBudgets(testMonth);
      expect(budgets['食費'], 30000);
    });

    testWidgets('負数や非数値は保存されずエラー表示になる', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.byKey(CategoryBudgetAppKeys.row('食費')));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.enterText(
        find.byKey(CategoryBudgetAppKeys.categoryBudget_amountField),
        '-5',
      );
      await tester.tap(
        find.byKey(CategoryBudgetAppKeys.categoryBudget_saveButton),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // ダイアログは開いたまま・リポジトリには保存されない
      expect(
        find.byKey(CategoryBudgetAppKeys.categoryBudget_editDialog),
        findsOneWidget,
      );
      expect(find.text('有効な金額を入力してください'), findsOneWidget);
      expect(await repository.loadBudgets(testMonth), isEmpty);

      await tester.enterText(
        find.byKey(CategoryBudgetAppKeys.categoryBudget_amountField),
        'abc',
      );
      await tester.tap(
        find.byKey(CategoryBudgetAppKeys.categoryBudget_saveButton),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(CategoryBudgetAppKeys.categoryBudget_editDialog),
        findsOneWidget,
      );
      expect(await repository.loadBudgets(testMonth), isEmpty);
    });

    testWidgets('0を保存すると未設定扱いになる', (tester) async {
      await repository.saveBudget(testMonth, '食費', 10000);
      await pumpScreen(tester);

      await tester.tap(find.byKey(CategoryBudgetAppKeys.row('食費')));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.enterText(
        find.byKey(CategoryBudgetAppKeys.categoryBudget_amountField),
        '0',
      );
      await tester.tap(
        find.byKey(CategoryBudgetAppKeys.categoryBudget_saveButton),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect((await repository.loadBudgets(testMonth)).containsKey('食費'),
          isFalse);
      final stateText =
          tester.widget<Text>(find.byKey(CategoryBudgetAppKeys.state('食費')));
      expect(stateText.data, '未設定');
    });

    testWidgets('解除ボタンで削除される', (tester) async {
      await repository.saveBudget(testMonth, '食費', 10000);
      await pumpScreen(tester);

      await tester.tap(find.byKey(CategoryBudgetAppKeys.row('食費')));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(
        find.byKey(CategoryBudgetAppKeys.categoryBudget_removeButton),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect((await repository.loadBudgets(testMonth)).containsKey('食費'),
          isFalse);
    });
  });

  group('配線: BudgetSettingsScreen', () {
    testWidgets('openButton が存在する', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BudgetSettingsScreen(
            repository: BudgetRepository(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(CategoryBudgetAppKeys.openButton),
        findsOneWidget,
      );
    });
  });
}