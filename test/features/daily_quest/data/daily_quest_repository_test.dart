import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/domain/models/daily_quest.dart';
import 'package:kozuchi/features/daily_quest/data/daily_quest_repository.dart';

void main() {
  group('DailyQuestRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('初期状態ではnullを返す', () async {
      final repo = DailyQuestRepository();
      final state = await repo.loadQuests();
      expect(state, isNull);
    });

    test('保存したクエスト状態を復元できる', () async {
      final repo = DailyQuestRepository();
      final quests = [
        DailyQuest(
          type: DailyQuestType.spendOnSelf,
          title: '自分に使え：¥1,000',
          description: '',
          targetValue: 1000,
          expReward: 80,
          satoriPenalty: 10,
        ),
      ];
      final state = DailyQuestState(quests: quests);

      await repo.saveQuests(state);

      final loaded = await repo.loadQuests();
      expect(loaded, isNotNull);
      expect(loaded!.quests.length, 1);
      expect(loaded.quests[0].type, DailyQuestType.spendOnSelf);
      expect(loaded.quests[0].title, '自分に使え：¥1,000');
    });

    test('複数クエストを保存・復元できる', () async {
      final repo = DailyQuestRepository();
      final quests = [
        DailyQuest(
          type: DailyQuestType.spendOnSelf,
          title: '自分に使え：¥1,000',
          description: '',
          targetValue: 1000,
          expReward: 80,
          satoriPenalty: 10,
        ).updateProgress(500),
        DailyQuest(
          type: DailyQuestType.receiptScan,
          title: 'レシートを3枚撮れ',
          description: '',
          targetValue: 3,
          expReward: 100,
          satoriPenalty: 10,
        ).updateProgress(3),
      ];
      final state = DailyQuestState(quests: quests);

      await repo.saveQuests(state);

      final loaded = await repo.loadQuests();
      expect(loaded!.quests.length, 2);
      expect(loaded.quests[0].currentProgress, 500);
      expect(loaded.quests[1].isCompleted, isTrue);
    });

    test('日付跨ぎを検出できる（別日の状態は無効）', () async {
      final repo = DailyQuestRepository();
      final oldDate = DateTime(2026, 6, 1);
      final quests = [
        DailyQuest(
          type: DailyQuestType.spendOnSelf,
          title: '古いクエスト',
          description: '',
          targetValue: 1000,
          expReward: 80,
          satoriPenalty: 10,
          dateAssigned: oldDate,
        ),
      ];
      final oldState = DailyQuestState(date: oldDate, quests: quests);

      await repo.saveQuests(oldState);

      // 今日の日付と異なる場合はnull相当とみなす
      final needsRefresh = await repo.needsRefresh();
      final today = DateTime.now();
      if (oldDate.year != today.year ||
          oldDate.month != today.month ||
          oldDate.day != today.day) {
        expect(needsRefresh, isTrue);
      }
    });

    test('同日の状態はリフレッシュ不要', () async {
      final repo = DailyQuestRepository();
      final quests = [
        DailyQuest(
          type: DailyQuestType.noSpending,
          title: '無支出の日',
          description: '',
          targetValue: 0,
          expReward: 150,
          satoriPenalty: 20,
        ),
      ];
      final state = DailyQuestState(quests: quests);

      await repo.saveQuests(state);

      // 保存直後なら同じ日のはず
      final needsRefresh = await repo.needsRefresh();
      expect(needsRefresh, isFalse);
    });

    test('クエストの進捗更新を保存できる', () async {
      final repo = DailyQuestRepository();
      final quest = DailyQuest(
        type: DailyQuestType.newCategory,
        title: '新カテゴリで支出',
        description: '',
        targetValue: 1,
        expReward: 120,
        satoriPenalty: 10,
      );
      final state = DailyQuestState(quests: [quest]);
      await repo.saveQuests(state);

      // 進捗を更新して上書き保存
      final updatedQuest = quest.updateProgress(1);
      final updatedState = DailyQuestState(quests: [updatedQuest]);
      await repo.saveQuests(updatedState);

      final loaded = await repo.loadQuests();
      expect(loaded!.quests[0].isCompleted, isTrue);
      expect(loaded.quests[0].dateCompleted, isNotNull);
    });

    test('全データを削除できる', () async {
      final repo = DailyQuestRepository();
      final quests = [
        DailyQuest(
          type: DailyQuestType.spendOnSelf,
          title: '自分に使え：¥1,000',
          description: '',
          targetValue: 1000,
          expReward: 80,
          satoriPenalty: 10,
        ),
      ];
      await repo.saveQuests(DailyQuestState(quests: quests));

      // 削除前はデータがある
      expect(await repo.loadQuests(), isNotNull);

      await repo.clearAll();

      // 削除後はnull
      expect(await repo.loadQuests(), isNull);
    });

    test('破損データに対してはnullを返す（クラッシュしない）', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('kozuchi_daily_quests_state', 'invalid json{{{');

      final repo = DailyQuestRepository();
      final state = await repo.loadQuests();
      expect(state, isNull);
    });
  });
}
