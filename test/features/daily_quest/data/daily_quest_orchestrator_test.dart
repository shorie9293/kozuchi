import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/domain/models/daily_quest.dart';
import 'package:kozuchi/features/daily_quest/data/daily_quest_orchestrator.dart';

void main() {
  group('DailyQuestOrchestrator', () {
    late DailyQuestOrchestrator orchestrator;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      orchestrator = const DailyQuestOrchestrator();
    });

    // デフォルトパラメータ（全クエストタイプ利用可能）
    Future<DailyQuestRefreshResult> _ensureWithDefaults() {
      return orchestrator.ensureQuestsForToday(
        budgetIsSet: true,
        dailyBudgetAmount: 3000,
        allCategoriesUsedRecently: false,
        yesterdayWasHighSpending: false,
      );
    }

    test('初回起動時は新規クエストが割り当てられる', () async {
      final result = await _ensureWithDefaults();

      expect(result.didRefresh, isTrue);
      expect(result.state.isToday, isTrue);
      expect(result.state.quests, isNotEmpty);
      expect(result.previousDayFailedQuests, isEmpty);
    });

    test('同日2回目の呼び出しではリフレッシュされない', () async {
      // 1回目: 新規割当
      final result1 = await _ensureWithDefaults();
      expect(result1.didRefresh, isTrue);

      // 2回目: 同日なのでリフレッシュ不要
      final result2 = await _ensureWithDefaults();
      expect(result2.didRefresh, isFalse);
      expect(result2.state.quests.length, result1.state.quests.length);
    });

    test('リフレッシュ後は最大3件のクエストが割り当てられる', () async {
      final result = await _ensureWithDefaults();
      expect(result.state.quests.length, lessThanOrEqualTo(3));
      expect(result.state.quests.isNotEmpty, isTrue);
    });

    test('リフレッシュ後のクエストはすべて未完了・未失敗状態', () async {
      final result = await _ensureWithDefaults();
      for (final quest in result.state.quests) {
        expect(quest.isCompleted, isFalse);
        expect(quest.isFailed, isFalse);
        expect(quest.currentProgress, 0);
      }
    });

    test('リフレッシュ後のクエストIDはすべて一意', () async {
      final result = await _ensureWithDefaults();
      final ids = result.state.quests.map((q) => q.id).toSet();
      expect(ids.length, result.state.quests.length);
    });

    test('保存したクエスト状態を読み出せる', () async {
      // まずリフレッシュして保存
      final result = await _ensureWithDefaults();
      expect(result.didRefresh, isTrue);

      // loadCurrentState で読み出し
      final loaded = await orchestrator.loadCurrentState();
      expect(loaded, isNotNull);
      expect(loaded!.quests.length, result.state.quests.length);
      for (int i = 0; i < loaded.quests.length; i++) {
        expect(loaded.quests[i].type, result.state.quests[i].type);
      }
    });

    test('手動でクエスト状態を保存できる', () async {
      final quest = DailyQuest(
        type: DailyQuestType.noSpending,
        title: '無支出の日',
        targetValue: 0,
      );
      final state = DailyQuestState(quests: [quest]);

      await orchestrator.saveState(state);
      final loaded = await orchestrator.loadCurrentState();

      expect(loaded, isNotNull);
      expect(loaded!.quests.length, 1);
      expect(loaded.quests[0].type, DailyQuestType.noSpending);
    });

    test('全データを削除できる', () async {
      // まずデータを作成
      await _ensureWithDefaults();
      expect(await orchestrator.loadCurrentState(), isNotNull);

      // 削除
      await orchestrator.clearAll();
      expect(await orchestrator.loadCurrentState(), isNull);
    });

    test('予算未設定時は underBudget が除外される', () async {
      final result = await orchestrator.ensureQuestsForToday(
        budgetIsSet: false,
        dailyBudgetAmount: 0,
        allCategoriesUsedRecently: true, // newCategoryも除外
        yesterdayWasHighSpending: false,
      );

      for (final quest in result.state.quests) {
        expect(quest.type, isNot(DailyQuestType.underBudget));
      }
    });

    test('全カテゴリ網羅時は newCategory が除外される', () async {
      final result = await orchestrator.ensureQuestsForToday(
        budgetIsSet: true,
        dailyBudgetAmount: 5000,
        allCategoriesUsedRecently: true,
        yesterdayWasHighSpending: false,
      );

      for (final quest in result.state.quests) {
        expect(quest.type, isNot(DailyQuestType.newCategory));
      }
    });

    test('前日の未完了クエストがある場合、didRefresh=trueかつ失敗クエストが返る', () async {
      // 別の日の状態を手動で保存（前日扱いにしたいがSharedPreferences制約で難しい）
      // ここでは orchestrator.saveState で過去日付の状態を保存してテストする
      final oldDate = DateTime(2020, 1, 1);
      final oldQuest = DailyQuest(
        type: DailyQuestType.spendOnSelf,
        title: '古いクエスト',
        targetValue: 1000,
        dateAssigned: oldDate,
      );
      final oldState = DailyQuestState(date: oldDate, quests: [oldQuest]);

      await orchestrator.saveState(oldState);

      // 今日の日付と異なるのでリフレッシュされる
      final result = await orchestrator.ensureQuestsForToday(
        budgetIsSet: true,
        dailyBudgetAmount: 3000,
        allCategoriesUsedRecently: false,
        yesterdayWasHighSpending: false,
      );

      expect(result.didRefresh, isTrue);
      // 前日の未完了クエストは失敗扱いに
      expect(result.previousDayFailedQuests.length, 1);
      expect(result.previousDayFailedQuests[0].isFailed, isTrue);
      expect(result.previousDayFailedQuests[0].type, DailyQuestType.spendOnSelf);
    });

    test('前日の全クエストが完了済みなら失敗クエストは空', () async {
      final oldDate = DateTime(2020, 1, 1);
      final completedQuest = DailyQuest(
        type: DailyQuestType.spendOnSelf,
        title: '完了済み',
        targetValue: 1000,
        dateAssigned: oldDate,
      ).updateProgress(1000); // 完了させる
      final oldState = DailyQuestState(date: oldDate, quests: [completedQuest]);

      await orchestrator.saveState(oldState);

      final result = await orchestrator.ensureQuestsForToday(
        budgetIsSet: true,
        dailyBudgetAmount: 3000,
        allCategoriesUsedRecently: false,
        yesterdayWasHighSpending: false,
      );

      expect(result.didRefresh, isTrue);
      // 完了済みなので失敗扱いされない
      expect(result.previousDayFailedQuests, isEmpty);
    });

    test('previousDaySatoriPenalty が正しく計算される', () async {
      final oldDate = DateTime(2020, 1, 1);
      final quest1 = DailyQuest(
        type: DailyQuestType.spendOnSelf,
        title: 'q1',
        targetValue: 1000,
        dateAssigned: oldDate,
      );
      final quest2 = DailyQuest(
        type: DailyQuestType.receiptScan,
        title: 'q2',
        targetValue: 3,
        dateAssigned: oldDate,
      );
      final oldState = DailyQuestState(date: oldDate, quests: [quest1, quest2]);

      await orchestrator.saveState(oldState);

      final result = await orchestrator.ensureQuestsForToday(
        budgetIsSet: true,
        dailyBudgetAmount: 3000,
        allCategoriesUsedRecently: false,
        yesterdayWasHighSpending: false,
      );

      expect(result.previousDayFailedQuests.length, 2);
      final expectedPenalty =
          DailyQuestType.spendOnSelf.defaultSatoriPenalty +
          DailyQuestType.receiptScan.defaultSatoriPenalty;
      expect(result.previousDaySatoriPenalty, expectedPenalty);
    });
  });
}
