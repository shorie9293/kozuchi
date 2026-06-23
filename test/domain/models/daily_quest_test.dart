import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/daily_quest.dart';

void main() {
  group('DailyQuestType', () {
    test('全クエストタイプが定義されている', () {
      expect(DailyQuestType.values.length, 5);
      expect(DailyQuestType.spendOnSelf.label, '自分に使え');
      expect(DailyQuestType.receiptScan.label, 'レシート撮影');
      expect(DailyQuestType.newCategory.label, '新カテゴリ支出');
      expect(DailyQuestType.underBudget.label, '予算以内');
      expect(DailyQuestType.noSpending.label, '無支出の日');
    });

    test('各タイプにデフォルトXP報酬が設定されている', () {
      expect(DailyQuestType.spendOnSelf.defaultExpReward, 80);
      expect(DailyQuestType.receiptScan.defaultExpReward, 100);
      expect(DailyQuestType.newCategory.defaultExpReward, 120);
      expect(DailyQuestType.underBudget.defaultExpReward, 60);
      expect(DailyQuestType.noSpending.defaultExpReward, 150);
    });

    test('各タイプにSATORIペナルティが設定されている', () {
      expect(DailyQuestType.spendOnSelf.defaultSatoriPenalty, 10);
      expect(DailyQuestType.receiptScan.defaultSatoriPenalty, 10);
      expect(DailyQuestType.newCategory.defaultSatoriPenalty, 10);
      expect(DailyQuestType.underBudget.defaultSatoriPenalty, 5);
      expect(DailyQuestType.noSpending.defaultSatoriPenalty, 20);
    });

    test('nameからenumを取得できる', () {
      expect(DailyQuestType.fromName('spendOnSelf'), DailyQuestType.spendOnSelf);
      expect(DailyQuestType.fromName('receiptScan'), DailyQuestType.receiptScan);
      expect(DailyQuestType.fromName('newCategory'), DailyQuestType.newCategory);
      expect(DailyQuestType.fromName('unknown'), DailyQuestType.spendOnSelf);
    });
  });

  group('DailyQuest', () {
    test('クエストを生成できる', () {
      final quest = DailyQuest(
        type: DailyQuestType.spendOnSelf,
        title: '自分に使え：¥1,000',
        description: '今日は自分のために¥1,000使おう',
        targetValue: 1000,
        expReward: 80,
        satoriPenalty: 10,
      );
      expect(quest.type, DailyQuestType.spendOnSelf);
      expect(quest.title, '自分に使え：¥1,000');
      expect(quest.targetValue, 1000);
      expect(quest.currentProgress, 0);
      expect(quest.isCompleted, isFalse);
      expect(quest.isFailed, isFalse);
      expect(quest.dateCompleted, isNull);
    });

    test('進捗を更新できる（目標未満）', () {
      final quest = DailyQuest(
        type: DailyQuestType.receiptScan,
        title: 'レシートを3枚撮れ',
        description: '今日のレシートを3枚撮影しよう',
        targetValue: 3,
        expReward: 100,
        satoriPenalty: 10,
      );
      final updated = quest.updateProgress(2);
      expect(updated.currentProgress, 2);
      expect(updated.isCompleted, isFalse);
      expect(updated.dateCompleted, isNull);
    });

    test('進捗が目標に達すると完了する', () {
      final quest = DailyQuest(
        type: DailyQuestType.receiptScan,
        title: 'レシートを3枚撮れ',
        description: '今日のレシートを3枚撮影しよう',
        targetValue: 3,
        expReward: 100,
        satoriPenalty: 10,
      );
      final updated = quest.updateProgress(3);
      expect(updated.currentProgress, 3);
      expect(updated.isCompleted, isTrue);
      expect(updated.dateCompleted, isNotNull);
    });

    test('進捗が目標を超えてもcurrentProgressは目標値でクランプされる', () {
      final quest = DailyQuest(
        type: DailyQuestType.spendOnSelf,
        title: '自分に使え：¥1,000',
        description: '今日は自分のために¥1,000使おう',
        targetValue: 1000,
        expReward: 80,
        satoriPenalty: 10,
      );
      final updated = quest.updateProgress(1500);
      expect(updated.currentProgress, 1000);
      expect(updated.isCompleted, isTrue);
    });

    test('完了済みクエストの進捗更新は完了状態を維持する', () {
      final quest = DailyQuest(
        type: DailyQuestType.spendOnSelf,
        title: '自分に使え：¥1,000',
        description: '今日は自分のために¥1,000使おう',
        targetValue: 1000,
        expReward: 80,
        satoriPenalty: 10,
      ).updateProgress(1000);

      final updated = quest.updateProgress(500);
      expect(updated.isCompleted, isTrue);
      expect(updated.currentProgress, 1000);
    });

    test('失敗としてマークできる', () {
      final quest = DailyQuest(
        type: DailyQuestType.noSpending,
        title: '無支出の日',
        description: '今日は1円も使わない',
        targetValue: 0,
        expReward: 150,
        satoriPenalty: 20,
      );
      final failed = quest.markAsFailed();
      expect(failed.isFailed, isTrue);
      expect(failed.isCompleted, isFalse);
    });

    test('進行度ゲッターが正しい', () {
      final quest = DailyQuest(
        type: DailyQuestType.receiptScan,
        title: 'レシートを3枚撮れ',
        description: '今日のレシートを3枚撮影しよう',
        targetValue: 3,
        expReward: 100,
        satoriPenalty: 10,
      ).updateProgress(1);
      expect(quest.progressRatio, 1 / 3);
    });

    test('目標値0の場合の進行度は1を返す（ゼロ除算回避）', () {
      final quest = DailyQuest(
        type: DailyQuestType.noSpending,
        title: '無支出の日',
        description: '今日は1円も使わない',
        targetValue: 0,
        expReward: 150,
        satoriPenalty: 20,
      );
      expect(quest.progressRatio, 1.0);
    });
  });

  group('DailyQuest JSON', () {
    test('toJson -> fromJson で復元できる', () {
      final quest = DailyQuest(
        type: DailyQuestType.newCategory,
        title: '新カテゴリで支出',
        description: '最近使っていないカテゴリで支出しよう',
        targetValue: 1,
        expReward: 120,
        satoriPenalty: 10,
      ).updateProgress(1);

      final json = quest.toJson();
      final restored = DailyQuest.fromJson(json);

      expect(restored.id, quest.id);
      expect(restored.type, quest.type);
      expect(restored.title, quest.title);
      expect(restored.description, quest.description);
      expect(restored.targetValue, quest.targetValue);
      expect(restored.currentProgress, quest.currentProgress);
      expect(restored.isCompleted, quest.isCompleted);
      expect(restored.expReward, quest.expReward);
      expect(restored.satoriPenalty, quest.satoriPenalty);
    });

    test('不完全なJSONからデフォルト値で復元できる', () {
      final json = <String, dynamic>{
        'type': 'underBudget',
        'title': '予算以内',
        'targetValue': 5000,
      };
      final quest = DailyQuest.fromJson(json);
      expect(quest.type, DailyQuestType.underBudget);
      expect(quest.description, '');
      expect(quest.currentProgress, 0);
      expect(quest.expReward, 60);
      expect(quest.satoriPenalty, 5);
    });

    test('dateCompleted のJSON復元', () {
      final quest = DailyQuest(
        type: DailyQuestType.spendOnSelf,
        title: '自分に使え：¥1,000',
        description: '',
        targetValue: 1000,
        expReward: 80,
        satoriPenalty: 10,
      ).updateProgress(1000);

      final json = quest.toJson();
      expect(json['dateCompleted'], isNotNull);
      expect(json['isCompleted'], true);
    });

    test('dateAssigned のJSON復元（存在しない場合は現在時刻）', () {
      final quest = DailyQuest.fromJson({
        'type': 'spendOnSelf',
        'title': 'test',
        'targetValue': 100,
      });
      expect(quest.dateAssigned, isNotNull);
    });
  });

  group('DailyQuestState', () {
    test('空の状態を生成できる', () {
      final state = DailyQuestState.empty();
      expect(state.quests, isEmpty);
    });

    test('クエストリストから状態を生成できる', () {
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
      expect(state.quests.length, 1);
      expect(state.isToday, isTrue);
    });

    test('未完了クエスト一覧を取得できる', () {
      final completed = DailyQuest(
        type: DailyQuestType.noSpending,
        title: '無支出の日',
        description: '',
        targetValue: 0,
        expReward: 150,
        satoriPenalty: 20,
      ).updateProgress(0);
      final pending = DailyQuest(
        type: DailyQuestType.receiptScan,
        title: 'レシートを3枚撮れ',
        description: '',
        targetValue: 3,
        expReward: 100,
        satoriPenalty: 10,
      );

      final state = DailyQuestState(quests: [completed, pending]);
      expect(state.pendingQuests.length, 1);
      expect(state.completedQuests.length, 1);
    });

    test('全クエスト完了判定', () {
      final allDone = [
        DailyQuest(
          type: DailyQuestType.spendOnSelf,
          title: '自分に使え：¥1,000',
          description: '',
          targetValue: 1000,
          expReward: 80,
          satoriPenalty: 10,
        ).updateProgress(1000),
      ];
      final state = DailyQuestState(quests: allDone);
      expect(state.isAllCompleted, isTrue);
    });

    test('SATORIペナルティ合計を計算できる', () {
      final quests = [
        DailyQuest(
          type: DailyQuestType.spendOnSelf,
          title: '自分に使え：¥1,000',
          description: '',
          targetValue: 1000,
          expReward: 80,
          satoriPenalty: 10,
        ).markAsFailed(),
        DailyQuest(
          type: DailyQuestType.receiptScan,
          title: 'レシートを3枚撮れ',
          description: '',
          targetValue: 3,
          expReward: 100,
          satoriPenalty: 10,
        ).markAsFailed(),
      ];
      final state = DailyQuestState(quests: quests);
      expect(state.totalSatoriPenalty, 20);
    });

    test('日付跨ぎ判定 - 別日ならisTodayがfalse', () {
      final oldDate = DateTime(2026, 6, 1);
      final state = DailyQuestState(
        quests: [],
        date: oldDate,
      );
      // 現在時刻と異なる日付ならisTodayはfalseになるはず
      // （テスト実行時の日付に依存するため、旧い日付ならfalseと期待）
      final today = DateTime.now();
      if (oldDate.year != today.year ||
          oldDate.month != today.month ||
          oldDate.day != today.day) {
        expect(state.isToday, isFalse);
      }
    });

    test('toJson -> fromJson で状態を復元できる', () {
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
        ),
      ];
      final state = DailyQuestState(quests: quests);
      final json = state.toJson();
      final restored = DailyQuestState.fromJson(json);

      expect(restored.quests.length, 2);
      expect(restored.quests[0].currentProgress, 500);
      expect(restored.quests[1].currentProgress, 0);
    });
  });
}
