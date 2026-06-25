import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/domain/models/daily_quest.dart';
import 'package:kozuchi/features/daily_quest/presentation/state/daily_quest_notifier.dart';

void main() {
  group('DailyQuestNotifier', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('初期状態は読み込み中', () {
      final notifier = DailyQuestNotifier();
      expect(notifier.isLoading, isTrue);
      expect(notifier.state, isNull);
      expect(notifier.errorMessage, isNull);
      expect(notifier.hasQuests, isFalse);
    });

    test('loadQuestsForTodayでクエストを読み込める', () async {
      final notifier = DailyQuestNotifier();

      await notifier.loadQuestsForToday(
        budgetIsSet: true,
        dailyBudgetAmount: 5000,
        allCategoriesUsedRecently: false,
        yesterdayWasHighSpending: false,
      );

      expect(notifier.isLoading, isFalse);
      expect(notifier.state, isNotNull);
      expect(notifier.hasQuests, isTrue);
      expect(notifier.errorMessage, isNull);
    });

    test('loadQuestsForTodayで割り当てられたクエストは最大3件', () async {
      final notifier = DailyQuestNotifier();

      await notifier.loadQuestsForToday(
        budgetIsSet: true,
        dailyBudgetAmount: 5000,
        allCategoriesUsedRecently: false,
        yesterdayWasHighSpending: false,
      );

      expect(notifier.state!.quests.length, lessThanOrEqualTo(3));
      expect(notifier.state!.quests.length, greaterThanOrEqualTo(1));
    });

    test('予算未設定時はunderBudgetが除外される', () async {
      final notifier = DailyQuestNotifier();

      await notifier.loadQuestsForToday(
        budgetIsSet: false,
        dailyBudgetAmount: 0,
        allCategoriesUsedRecently: false,
        yesterdayWasHighSpending: false,
      );

      // underBudgetタイプがあってはいけない
      for (final quest in notifier.state!.quests) {
        expect(quest.type, isNot(DailyQuestType.underBudget));
      }
    });

    test('updateQuestProgressで進捗を更新できる', () async {
      final notifier = DailyQuestNotifier();

      await notifier.loadQuestsForToday(
        budgetIsSet: true,
        dailyBudgetAmount: 5000,
        allCategoriesUsedRecently: false,
        yesterdayWasHighSpending: false,
      );

      final quest = notifier.state!.quests.first;
      if (quest.type == DailyQuestType.noSpending) {
        // noSpendingは進捗更新が無意味なのでスキップ
        return;
      }

      final questId = quest.id;
      notifier.updateQuestProgress(questId, quest.targetValue);

      final updated = notifier.state!.quests.firstWhere((q) => q.id == questId);
      expect(updated.isCompleted, isTrue);
      expect(updated.progressRatio, 1.0);
    });

    test('完了済みクエスト一覧を取得できる', () async {
      final notifier = DailyQuestNotifier();

      await notifier.loadQuestsForToday(
        budgetIsSet: true,
        dailyBudgetAmount: 5000,
        allCategoriesUsedRecently: false,
        yesterdayWasHighSpending: false,
      );

      // 初期状態では完了しているクエストはない
      expect(notifier.completedQuests, isEmpty);

      // 全クエストを完了させる
      for (final quest in notifier.state!.quests) {
        if (quest.type == DailyQuestType.noSpending) continue;
        notifier.updateQuestProgress(quest.id, quest.targetValue);
      }

      // 全クエスト達成になる（noSpending以外）
      final done = notifier.completedQuests;
      expect(done.length, greaterThanOrEqualTo(1));
    });

    test('isAllCompletedは全クエスト達成時のみtrue', () async {
      final notifier = DailyQuestNotifier();

      await notifier.loadQuestsForToday(
        budgetIsSet: true,
        dailyBudgetAmount: 5000,
        allCategoriesUsedRecently: false,
        yesterdayWasHighSpending: false,
      );

      // 初期状態では全達成ではない
      expect(notifier.isAllCompleted, isFalse);

      // 全クエストを完了させる
      for (final quest in notifier.state!.quests) {
        notifier.updateQuestProgress(quest.id, quest.targetValue);
      }

      expect(notifier.isAllCompleted, isTrue);
    });

    test('setStateで状態を直接設定できる', () {
      final notifier = DailyQuestNotifier();
      final quest = DailyQuest(
        type: DailyQuestType.spendOnSelf,
        title: 'テストクエスト',
        description: 'テスト',
        targetValue: 1000,
      );
      final state = DailyQuestState(quests: [quest]);

      notifier.setState(state);

      expect(notifier.isLoading, isFalse);
      expect(notifier.state!.quests.length, 1);
      expect(notifier.state!.quests[0].title, 'テストクエスト');
    });

    test('pendingQuestsは未完了クエストのみを返す', () async {
      final notifier = DailyQuestNotifier();

      await notifier.loadQuestsForToday(
        budgetIsSet: true,
        dailyBudgetAmount: 5000,
        allCategoriesUsedRecently: false,
        yesterdayWasHighSpending: false,
      );

      final allCount = notifier.state!.quests.length;

      // 最初のクエストを完了させる
      final firstQuest = notifier.state!.quests.first;
      if (firstQuest.type != DailyQuestType.noSpending) {
        notifier.updateQuestProgress(firstQuest.id, firstQuest.targetValue);
      }

      final pending = notifier.pendingQuests;
      // 少なくとも1つは完了している
      if (allCount > 1) {
        expect(pending.length, lessThan(allCount));
      }
    });

    test('loadCurrentStateで保存済み状態を読み込める', () async {
      final notifier = DailyQuestNotifier();

      // まずクエストを割り当てて保存
      await notifier.loadQuestsForToday(
        budgetIsSet: true,
        dailyBudgetAmount: 5000,
        allCategoriesUsedRecently: false,
        yesterdayWasHighSpending: false,
      );
      await notifier.persist();

      // 新しいnotifierで読み込み
      final notifier2 = DailyQuestNotifier();
      await notifier2.loadCurrentState();

      expect(notifier2.state, isNotNull);
      expect(notifier2.hasQuests, isTrue);
    });
  });
}
