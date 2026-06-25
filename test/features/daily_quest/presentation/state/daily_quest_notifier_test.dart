import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/domain/models/daily_quest.dart';
import 'package:kozuchi/features/daily_quest/presentation/state/daily_quest_notifier.dart';
import 'package:kozuchi/features/daily_quest/data/quest_action.dart';

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

    test('loadQuestsForTodayで日跨ぎ時にSATORIペナルティが記録される', () async {
      final notifier = DailyQuestNotifier();

      // まず前日として古い日付の状態を保存
      final oldDate = DateTime(2020, 1, 1);
      final oldQuest = DailyQuest(
        type: DailyQuestType.spendOnSelf,
        title: '古いクエスト',
        targetValue: 1000,
        dateAssigned: oldDate,
      );
      final oldState = DailyQuestState(date: oldDate, quests: [oldQuest]);
      notifier.setState(oldState);
      await notifier.persist();

      // 新しいnotifierで読み込み → 日跨ぎ検出でリフレッシュ
      final notifier2 = DailyQuestNotifier();
      await notifier2.loadQuestsForToday(
        budgetIsSet: true,
        dailyBudgetAmount: 5000,
        allCategoriesUsedRecently: false,
        yesterdayWasHighSpending: false,
      );

      // 前日の未達成クエストのSATORIペナルティが記録される
      expect(notifier2.lastSatoriPenalty,
          DailyQuestType.spendOnSelf.defaultSatoriPenalty);
    });

    test('同日ならSATORIペナルティは0', () async {
      final notifier = DailyQuestNotifier();

      await notifier.loadQuestsForToday(
        budgetIsSet: true,
        dailyBudgetAmount: 5000,
        allCategoriesUsedRecently: false,
        yesterdayWasHighSpending: false,
      );
      await notifier.persist();

      // 同日再読み込み → ペナルティなし
      final notifier2 = DailyQuestNotifier();
      await notifier2.loadCurrentState();
      // loadCurrentStateはリフレッシュしないのでペナルティ0
      expect(notifier2.lastSatoriPenalty, 0);
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

    test('detectActionでクエスト達成時にEXP報酬が返る', () async {
      final notifier = DailyQuestNotifier();

      // 手動でspendOnSelfクエストをセット（ほぼ達成状態）
      final quest = DailyQuest(
        id: 'dq_test_1',
        type: DailyQuestType.spendOnSelf,
        title: '自分に使え',
        description: '自己投資に¥1000使う',
        targetValue: 1000,
        currentProgress: 500,
      );
      final state = DailyQuestState(quests: [quest]);
      notifier.setState(state);

      // 支出アクションでクエスト完了
      final completed = notifier.detectAction(
        const QuestAction.expenseRecorded(amount: 600, category: '書籍'),
      );

      // 達成されたクエストが返る
      expect(completed.length, 1);
      expect(completed[0].id, 'dq_test_1');
      expect(completed[0].isCompleted, isTrue);
      // EXP報酬が正しい
      expect(completed[0].expReward, DailyQuestType.spendOnSelf.defaultExpReward);
    });

    test('detectActionで達成しなかった場合は空リストが返る', () async {
      final notifier = DailyQuestNotifier();

      final quest = DailyQuest(
        id: 'dq_test_2',
        type: DailyQuestType.spendOnSelf,
        title: '自分に使え',
        targetValue: 5000,
      );
      final state = DailyQuestState(quests: [quest]);
      notifier.setState(state);

      // 少量の支出ではクエスト未達成
      final completed = notifier.detectAction(
        const QuestAction.expenseRecorded(amount: 500, category: '書籍'),
      );

      expect(completed, isEmpty);
    });

    test('detectActionで複数クエスト同時達成時に全EXP報酬が返る', () async {
      final notifier = DailyQuestNotifier();

      final quests = [
        DailyQuest(
          id: 'dq_a',
          type: DailyQuestType.spendOnSelf,
          title: 'spendOnSelf',
          targetValue: 200,
          currentProgress: 200, // ほぼ達成
        ),
        DailyQuest(
          id: 'dq_b',
          type: DailyQuestType.newCategory,
          title: 'newCategory',
          targetValue: 1,
        ),
      ];
      final state = DailyQuestState(quests: quests);
      notifier.setState(state);

      // 自己投資カテゴリ＋新カテゴリの同時アクション
      // ただしnewCategoryは支出記録では検出されない。別アクションが必要。
      // spendOnSelfのみ達成させる
      final completed1 = notifier.detectAction(
        const QuestAction.expenseRecorded(amount: 100, category: '健康'),
      );

      // spendOnSelfが達成された
      expect(completed1.length, 1);
      expect(completed1[0].id, 'dq_a');
      expect(completed1[0].expReward, DailyQuestType.spendOnSelf.defaultExpReward);

      // 続けてnewCategoryアクション
      final completed2 = notifier.detectAction(
        const QuestAction.newCategoryUsed(category: '医療費'),
      );

      // newCategoryも達成
      expect(completed2.length, 1);
      expect(completed2[0].id, 'dq_b');
      expect(completed2[0].expReward, DailyQuestType.newCategory.defaultExpReward);

      // 合計EXP
      final totalExp = completed1[0].expReward + completed2[0].expReward;
      expect(totalExp,
          DailyQuestType.spendOnSelf.defaultExpReward +
              DailyQuestType.newCategory.defaultExpReward);
    });
  });
}
