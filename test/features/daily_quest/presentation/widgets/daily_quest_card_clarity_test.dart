import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/daily_quest.dart';
import 'package:kozuchi/features/daily_quest/presentation/widgets/daily_quest_card.dart';

void main() {
  group('DailyQuestCard - 完了条件の明確さ', () {
    testWidgets('spendOnSelfに条件説明が表示される', (tester) async {
      final quest = DailyQuest(
        type: DailyQuestType.spendOnSelf,
        title: '自分に使え：¥1,000',
        description: 'テスト',
        targetValue: 1000,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DailyQuestCard(quest: quest),
        ),
      ));

      // 自己投資カテゴリの支出が必要という説明が表示されている
      expect(
        find.textContaining('自己投資'),
        findsWidgets,
      );
    });

    testWidgets('receiptScanに条件説明が表示される', (tester) async {
      final quest = DailyQuest(
        type: DailyQuestType.receiptScan,
        title: 'レシートを3枚撮れ',
        description: 'テスト',
        targetValue: 3,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DailyQuestCard(quest: quest),
        ),
      ));

      // レシート撮影が必要という説明が表示されている
      expect(
        find.textContaining('レシート'),
        findsWidgets,
      );
    });

    testWidgets('noSpendingに「支出発生で失敗」と表示される', (tester) async {
      final quest = DailyQuest(
        type: DailyQuestType.noSpending,
        title: '無支出の日',
        description: '今日は1円も使わない',
        targetValue: 0,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DailyQuestCard(quest: quest),
        ),
      ));

      // 支出発生で失敗することが示されている
      expect(
        find.textContaining('支出'),
        findsWidgets,
      );
    });

    testWidgets('underBudgetに条件説明が表示される', (tester) async {
      final quest = DailyQuest(
        type: DailyQuestType.underBudget,
        title: '今日は¥5,000以内',
        description: 'テスト',
        targetValue: 5000,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DailyQuestCard(quest: quest),
        ),
      ));

      // 予算以内という説明が表示されている
      expect(
        find.textContaining('予算'),
        findsWidgets,
      );
    });

    testWidgets('newCategoryに条件説明が表示される', (tester) async {
      final quest = DailyQuest(
        type: DailyQuestType.newCategory,
        title: '新カテゴリで支出せよ',
        description: 'テスト',
        targetValue: 1,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DailyQuestCard(quest: quest),
        ),
      ));

      // 新カテゴリでの支出が必要という説明が表示されている
      expect(
        find.textContaining('カテゴリ'),
        findsWidgets,
      );
    });

    testWidgets('目標値と現在値が進捗表示されている', (tester) async {
      final quest = DailyQuest(
        type: DailyQuestType.spendOnSelf,
        title: '自分に使え：¥1,000',
        description: 'テスト',
        targetValue: 1000,
        currentProgress: 500,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DailyQuestCard(quest: quest),
        ),
      ));

      // 進捗数値が表示されている
      expect(find.text('500 / 1000'), findsOneWidget);
    });

    testWidgets('完了したクエストには達成バッジが表示される', (tester) async {
      final quest = DailyQuest(
        type: DailyQuestType.receiptScan,
        title: 'レシートを3枚撮れ',
        description: 'テスト',
        targetValue: 3,
      ).updateProgress(3);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DailyQuestCard(quest: quest),
        ),
      ));

      expect(find.text('達成'), findsOneWidget);
    });

    testWidgets('失敗したクエストには失敗バッジが表示される', (tester) async {
      final quest = DailyQuest(
        type: DailyQuestType.noSpending,
        title: '無支出の日',
        description: 'テスト',
        targetValue: 0,
      ).markAsFailed();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DailyQuestCard(quest: quest),
        ),
      ));

      // 少なくとも1つの「失敗」表示がある
      expect(find.text('失敗'), findsWidgets);
      // SATORIペナルティ表示がある
      expect(find.textContaining('SATORI'), findsOneWidget);
    });
  });
}
