import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/features/budget/data/category_budget_repository.dart';
import 'package:kozuchi/features/budget/domain/category_budget_suggestion_service.dart';
import 'package:kozuchi/features/budget/presentation/category_budget_app_keys.dart';
import 'package:kozuchi/features/budget/presentation/category_budget_suggestion_app_keys.dart';
import 'package:kozuchi/features/budget/presentation/screens/category_budget_screen.dart';
import 'package:kozuchi/features/budget/presentation/screens/category_budget_suggestion_screen.dart';

/// 親探針: 合成の不変条件（子の個別試練では撃たれない組み合わせを撃つ）
///
/// 1. 画面の「この額を設定」→リポジトリ永続化→別インスタンスの
///    [CategoryBudgetScreen] にその予算が現れるか（state だけ更新して
///    永続化を忘れる型を撃つ）
/// 2. 画面に表示される推奨額が [CategoryBudgetSuggestionService] の
///    算出値と完全一致するか（表示とロジックの取り違えを撃つ）
/// 3. 窓外の古い支出のみのときは推奨が空になるか（窓の境界）
void main() {
  final now = DateTime(2026, 10, 11);

  ExpenseEntry entry(String id, int amount, String category, DateTime date) =>
      ExpenseEntry(id: id, amount: amount, category: category, date: date);

  // 直近3ヶ月すべてに同額の支出
  final uniform = <ExpenseEntry>[
    entry('a1', 30000, '食費', DateTime(2026, 10, 5)),
    entry('a2', 30000, '食費', DateTime(2026, 9, 5)),
    entry('a3', 30000, '食費', DateTime(2026, 8, 5)),
    entry('b1', 5000, '交通費', DateTime(2026, 9, 20)),
  ];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('探針1: 適用→永続化→別画面に反映される合成', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CategoryBudgetSuggestionScreen(
          entriesLoader: () async => uniform,
          clock: () => now,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 食費: 3ヶ月均等で平均30000 → 推奨30000
    expect(
      find.byKey(CategoryBudgetSuggestionAppKeys.applyButton('食費')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(CategoryBudgetSuggestionAppKeys.applyButton('食費')),
    );
    await tester.pumpAndSettle();

    // リポジトリへ到達したことを読戻しで実測
    final saved = await const CategoryBudgetRepository().loadBudgets('2026-10');
    expect(saved['食費'], 30000);

    // 別インスタンスの CategoryBudgetScreen に予算が反映される
    await tester.pumpWidget(
      MaterialApp(
        home: CategoryBudgetScreen(
          repository: const CategoryBudgetRepository(),
          categories: const ['食費', '交通費'],
          yearMonth: '2026-10',
          spentLoader: (_) async => const {'食費': 10000},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(CategoryBudgetAppKeys.row('食費')), findsOneWidget);
    // 食費の行に予算 30000 が現れる（未設定=0 でないことの証明）
    expect(find.text('¥10000 / ¥30000'), findsOneWidget);
  });

  testWidgets('探針2: 画面表示の推奨額がサービスの算出値と一致する', (tester) async {
    final expected = const CategoryBudgetSuggestionService().suggest(
      entries: uniform,
      now: now,
    );
    expect(expected, isNotEmpty);

    await tester.pumpWidget(
      MaterialApp(
        home: CategoryBudgetSuggestionScreen(
          entriesLoader: () async => uniform,
          clock: () => now,
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final s in expected) {
      expect(
        find.text('推奨 ¥${s.recommendedBudget}'),
        findsWidgets,
        reason: 'カテゴリ ${s.category} の推奨額が表示と一致しない',
      );
      expect(
        find.byKey(CategoryBudgetSuggestionAppKeys.recommended(s.category)),
        findsOneWidget,
      );
    }
    // 食費(30000)が交通費(5000)より上位（recommendedBudget 降順）
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .where((d) => d != null)
        .toList();
    final iFood = texts.indexWhere((t) => t!.contains('食費'));
    final iTransit = texts.indexWhere((t) => t!.contains('交通費'));
    expect(iFood, lessThan(iTransit));
  });

  testWidgets('探針3: 窓外(4ヶ月前以前)の支出のみなら推奨は空', (tester) async {
    final outside = <ExpenseEntry>[
      entry('o1', 99999, '食費', DateTime(2026, 1, 5)),
      entry('o2', 99999, '食費', DateTime(2025, 12, 5)),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: CategoryBudgetSuggestionScreen(
          entriesLoader: () async => outside,
          clock: () => now,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(CategoryBudgetSuggestionAppKeys.emptyState),
      findsOneWidget,
    );
    expect(
      find.byKey(CategoryBudgetSuggestionAppKeys.applyButton('食費')),
      findsNothing,
    );
  });
}
