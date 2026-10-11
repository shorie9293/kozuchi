import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/features/budget/data/category_budget_repository.dart';
import 'package:kozuchi/features/budget/domain/category_budget_suggestion_service.dart';
import 'package:kozuchi/features/budget/presentation/category_budget_suggestion_app_keys.dart';
import 'package:kozuchi/features/budget/presentation/screens/category_budget_screen.dart';
import 'package:kozuchi/features/budget/presentation/screens/category_budget_suggestion_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

ExpenseEntry _entry({
  required String id,
  required int amount,
  required String category,
  required DateTime date,
}) =>
    ExpenseEntry(id: id, amount: amount, category: category, date: date);

/// 既定の固定日時（2026-10-15）
DateTime fixedNow() => DateTime(2026, 10, 15);

/// 固定エントリ（食費のみ）
List<ExpenseEntry> fixedEntries() => [
      _entry(
        id: 'e1',
        amount: 12000,
        category: '食費',
        date: DateTime(2026, 10, 1),
      ),
      _entry(
        id: 'e2',
        amount: 9000,
        category: '食費',
        date: DateTime(2026, 9, 10),
      ),
      _entry(
        id: 'e3',
        amount: 30000,
        category: '食費',
        date: DateTime(2026, 8, 20),
      ),
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpSuggestion(
    WidgetTester tester, {
    Future<List<ExpenseEntry>> Function()? entriesLoader,
    DateTime Function()? clock,
    int monthsToConsider =
        CategoryBudgetSuggestionService.defaultMonthsToConsider,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CategoryBudgetSuggestionScreen(
          entriesLoader: entriesLoader,
          clock: clock,
          monthsToConsider: monthsToConsider,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('固定エントリから推奨行が表示される（row/recommended キー）', (tester) async {
    await pumpSuggestion(
      tester,
      entriesLoader: () async => fixedEntries(),
      clock: fixedNow,
    );

    expect(
      find.byKey(CategoryBudgetSuggestionAppKeys.row('食費')),
      findsOneWidget,
    );
    final recommendedFinder = find.byKey(
      CategoryBudgetSuggestionAppKeys.recommended('食費'),
    );
    expect(recommendedFinder, findsOneWidget);
    // 平均 (12000+9000+30000)/3 = 17000 → 1000円単位切り上げで 17000
    final text = tester.widget<Text>(recommendedFinder);
    expect(text.data, '推奨 ¥17000');
  });

  testWidgets('説明文に monthsToConsider が反映される', (tester) async {
    await pumpSuggestion(
      tester,
      entriesLoader: () async => fixedEntries(),
      clock: fixedNow,
      monthsToConsider: 2,
    );

    expect(find.textContaining('過去 2 ヶ月の支出実績から'), findsOneWidget);
  });

  testWidgets('「この額を設定」タップで repository に保存され appliedMark が出る', (tester) async {
    await pumpSuggestion(
      tester,
      entriesLoader: () async => fixedEntries(),
      clock: fixedNow,
    );

    await tester.tap(
      find.byKey(CategoryBudgetSuggestionAppKeys.applyButton('食費')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(CategoryBudgetSuggestionAppKeys.appliedMark('食費')),
      findsOneWidget,
    );
    // SnackBar の確認
    expect(find.textContaining('の予算を ¥17000 に設定しました'), findsOneWidget);

    // SharedPreferences から実測読戻し
    final budgets = await const CategoryBudgetRepository()
        .loadBudgets('2026-10');
    expect(budgets['食費'], 17000);
  });

  testWidgets('空 entries で emptyState が出る', (tester) async {
    await pumpSuggestion(
      tester,
      entriesLoader: () async => <ExpenseEntry>[],
      clock: fixedNow,
    );

    expect(
      find.byKey(CategoryBudgetSuggestionAppKeys.emptyState),
      findsOneWidget,
    );
    expect(find.textContaining('推奨できるカテゴリがありません'), findsOneWidget);
  });

  testWidgets('loader が例外を投げてもクラッシュせずエラー文が出る', (tester) async {
    await pumpSuggestion(
      tester,
      entriesLoader: () async => throw Exception('network down'),
      clock: fixedNow,
    );

    expect(find.text('支出データの読み込みに失敗しました'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('読込中は loading キーが出る', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CategoryBudgetSuggestionScreen(
          entriesLoader: () => neverCompletingEntries,
          clock: fixedNow,
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(CategoryBudgetSuggestionAppKeys.loading),
      findsOneWidget,
    );
  });

  testWidgets('clock を固定すると yearMonth が YYYY-MM 形式で保存される', (tester) async {
    await pumpSuggestion(
      tester,
      entriesLoader: () async => [
        _entry(
          id: 'e1',
          amount: 5000,
          category: '交通費',
          date: DateTime(2027, 1, 5),
        ),
      ],
      clock: () => DateTime(2027, 1, 3),
    );

    await tester.tap(
      find.byKey(CategoryBudgetSuggestionAppKeys.applyButton('交通費')),
    );
    await tester.pumpAndSettle();

    // 適用済みマークが出る
    expect(
      find.byKey(CategoryBudgetSuggestionAppKeys.appliedMark('交通費')),
      findsOneWidget,
    );
    // 'YYYY-MM' 形式のキーで読戻せる（固定 clock の月 = 2027-01）
    final budgets = await const CategoryBudgetRepository()
        .loadBudgets('2027-01');
    expect(budgets['交通費'], 5000);
  });

  testWidgets('月をまたぐ窓の外の支出は集計されない', (tester) async {
    await pumpSuggestion(
      tester,
      entriesLoader: () async => [
        _entry(
          id: 'e1',
          amount: 6000,
          category: '娯楽',
          date: DateTime(2026, 10, 2),
        ),
        // 窓（2026-08〜2026-10）の外
        _entry(
          id: 'e2',
          amount: 99999,
          category: '娯楽',
          date: DateTime(2026, 4, 2),
        ),
      ],
      clock: fixedNow,
    );

    final text = tester.widget<Text>(
      find.byKey(
        CategoryBudgetSuggestionAppKeys.recommended('娯楽'),
      ),
    );
    // 窓内のみ: 平均6000 → 推奨6000
    expect(text.data, '推奨 ¥6000');
  });

  testWidgets('CategoryBudgetScreen の openButton から遷移する', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(
        home: CategoryBudgetScreen(
          categories: ['食費'],
          spentLoader: _stubSpentLoader,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(CategoryBudgetSuggestionAppKeys.openButton),
    );
    // pumpAndSettle は使わない: 遷移先の既定ローダが Supabase を呼ぶため
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // route が積まれ、遷移先画面が構築されたことを確認
    final route = tester.element(
      find.byKey(CategoryBudgetSuggestionAppKeys.suggestionScreen),
    );
    expect(ModalRoute.of(route)?.isCurrent ?? false, isTrue);
  });
}

Future<Map<String, int>> _stubSpentLoader(String yearMonth) async =>
    <String, int>{'食費': 1000};

/// 決して完了しないFuture（読込中状態の検証用）
final neverCompletingEntries =
    Completer<List<ExpenseEntry>>().future;