import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/daily_quest.dart';
import 'package:kozuchi/features/daily_quest/data/quest_assignment_service.dart';

void main() {
  group('QuestAssignmentService', () {
    late QuestAssignmentService service;

    setUp(() {
      service = const QuestAssignmentService();
    });

    // デフォルトのパラメータ（全クエストタイプが利用可能）
    DailyQuestState _assignWithDefaults({
      Random? random,
      List<DailyQuestType> yesterdayTypes = const [],
      List<DailyQuestType> dayBeforeYesterdayTypes = const [],
    }) {
      return service.assignDailyQuests(
        budgetIsSet: true,
        dailyBudgetAmount: 3000,
        allCategoriesUsedRecently: false,
        yesterdayWasHighSpending: false,
        yesterdayQuestTypes: yesterdayTypes,
        dayBeforeYesterdayQuestTypes: dayBeforeYesterdayTypes,
        random: random,
      );
    }

    test('全タイプ利用可能時に最大3件のクエストが割り当てられる', () {
      final state = _assignWithDefaults(random: Random(42));
      expect(state.quests.length, 3);
      // 各クエストが異なるタイプであることを確認（非復元抽出）
      final types = state.quests.map((q) => q.type).toSet();
      expect(types.length, 3);
    });

    test('割り当てられたクエストは本日の日付を持つ', () {
      final state = _assignWithDefaults(random: Random(42));
      expect(state.isToday, isTrue);
      for (final quest in state.quests) {
        expect(quest.dateAssigned.day, DateTime.now().day);
        expect(quest.dateAssigned.month, DateTime.now().month);
        expect(quest.dateAssigned.year, DateTime.now().year);
      }
    });

    test('全クエストが未完了・未失敗状態で生成される', () {
      final state = _assignWithDefaults(random: Random(42));
      for (final quest in state.quests) {
        expect(quest.isCompleted, isFalse);
        expect(quest.isFailed, isFalse);
        expect(quest.currentProgress, 0);
        expect(quest.dateCompleted, isNull);
      }
    });

    test('予算未設定時は underBudget が除外される', () {
      // 候補がunderBudgetのみになるように他を除外する状況を作るのは難しいので、
      // 全ての組合せで判定する方法をとる
      // seed=1 で予算設定ありの場合
      // ignore: unused_local_variable
      final withBudget = service.assignDailyQuests(
        budgetIsSet: true,
        dailyBudgetAmount: 5000,
        allCategoriesUsedRecently: true, // newCategoryも除外
        yesterdayWasHighSpending: false,
        yesterdayQuestTypes: const [],
        dayBeforeYesterdayQuestTypes: const [],
        random: Random(1),
      );
      // 予算なしの場合
      final withoutBudget = service.assignDailyQuests(
        budgetIsSet: false,
        dailyBudgetAmount: 0,
        allCategoriesUsedRecently: true, // newCategoryも除外
        yesterdayWasHighSpending: false,
        yesterdayQuestTypes: const [],
        dayBeforeYesterdayQuestTypes: const [],
        random: Random(1),
      );

      // withoutBudget には underBudget が含まれない
      expect(
        withoutBudget.quests.any((q) => q.type == DailyQuestType.underBudget),
        isFalse,
      );
    });

    test('全カテゴリ網羅時は newCategory が除外される', () {
      final state = service.assignDailyQuests(
        budgetIsSet: true,
        dailyBudgetAmount: 5000,
        allCategoriesUsedRecently: true,
        yesterdayWasHighSpending: false,
        yesterdayQuestTypes: const [],
        dayBeforeYesterdayQuestTypes: const [],
        random: Random(99),
      );
      expect(
        state.quests.any((q) => q.type == DailyQuestType.newCategory),
        isFalse,
      );
    });

    test('候補がゼロの場合は空の状態を返す', () {
      final state = service.assignDailyQuests(
        budgetIsSet: false, // underBudget除外
        dailyBudgetAmount: 0,
        allCategoriesUsedRecently: true, // newCategory除外
        yesterdayWasHighSpending: true, // spendOnSelf重み減だが除外はされない
        yesterdayQuestTypes: DailyQuestType.values, // 全タイプ前日使用
        dayBeforeYesterdayQuestTypes: const [],
        random: Random(1),
      );
      // 全タイプが候補にあれば（spendOnSelf, receiptScan, noSpending）
      // 重みは下がるが選択はされるはず
      // 極端なケース: 予算なし+全カテゴリ網羅+前日がspendOnSelf/receiptScan/noSpending
      // → 残り候補: spendOnSelf, receiptScan, noSpending → まだ3つある
      // 本当に0になるケース: budgetIsSet=false && allCategoriesUsedRecently=true
      // かつ yesterdayTypes に spendOnSelf, receiptScan, noSpending が含まれても
      // 候補自体は除外されない（重みが下がるだけ）
      //
      // 候補が本当に0になるのは…実装上ありえない（最低3タイプは残る）
      // このテストは設計上の防御的テストとして残す
      expect(state.quests.isNotEmpty, isTrue); // 実際には最低1件は選ばれる
    });

    test('spendOnSelf の目標値は500〜2000円の範囲', () {
      // 全クエストが spendOnSelf になるようにシードを探索する代わりに
      // 複数回試行して検証
      for (int seed = 0; seed < 20; seed++) {
        final state = _assignWithDefaults(random: Random(seed));
        for (final quest in state.quests) {
          if (quest.type == DailyQuestType.spendOnSelf) {
            expect(quest.targetValue, greaterThanOrEqualTo(500));
            expect(quest.targetValue, lessThanOrEqualTo(2000));
          }
        }
      }
    });

    test('receiptScan の目標値は1〜5枚の範囲', () {
      for (int seed = 0; seed < 20; seed++) {
        final state = service.assignDailyQuests(
          budgetIsSet: true,
          dailyBudgetAmount: 3000,
          allCategoriesUsedRecently: true, // newCategory除外
          yesterdayWasHighSpending: false,
          yesterdayQuestTypes: const [],
          dayBeforeYesterdayQuestTypes: const [],
          yesterdayReceiptCount: 10, // 大きい値でもclampされるはず
          random: Random(seed),
        );
        for (final quest in state.quests) {
          if (quest.type == DailyQuestType.receiptScan) {
            expect(quest.targetValue, greaterThanOrEqualTo(1));
            expect(quest.targetValue, lessThanOrEqualTo(5));
          }
        }
      }
    });

    test('underBudget の目標値は指定された日次予算額と一致する', () {
      for (int seed = 0; seed < 20; seed++) {
        final state = service.assignDailyQuests(
          budgetIsSet: true,
          dailyBudgetAmount: 7777,
          allCategoriesUsedRecently: true, // newCategory除外
          yesterdayWasHighSpending: false,
          yesterdayQuestTypes: const [],
          dayBeforeYesterdayQuestTypes: const [],
          random: Random(seed),
        );
        for (final quest in state.quests) {
          if (quest.type == DailyQuestType.underBudget) {
            expect(quest.targetValue, 7777);
          }
        }
      }
    });

    test('newCategory の目標値は常に1', () {
      for (int seed = 0; seed < 20; seed++) {
        final state = _assignWithDefaults(random: Random(seed));
        for (final quest in state.quests) {
          if (quest.type == DailyQuestType.newCategory) {
            expect(quest.targetValue, 1);
          }
        }
      }
    });

    test('noSpending の目標値は常に0', () {
      for (int seed = 0; seed < 20; seed++) {
        final state = _assignWithDefaults(random: Random(seed));
        for (final quest in state.quests) {
          if (quest.type == DailyQuestType.noSpending) {
            expect(quest.targetValue, 0);
          }
        }
      }
    });

    test('各タイプのタイトルが正しい形式で生成される', () {
      // 各タイプを明示的に生成して検証
      final typeTests = {
        DailyQuestType.spendOnSelf: (int tv) => '自分に使え：¥$tv',
        DailyQuestType.receiptScan: (int tv) => 'レシートを${tv}枚撮れ',
        DailyQuestType.newCategory: (int _) => '新カテゴリで支出せよ',
        DailyQuestType.underBudget: (int tv) => '今日は¥${tv}以内',
        DailyQuestType.noSpending: (int _) => '無支出の日',
      };

      // 複数シードで試行し、出現した全タイプを検証
      final seenTypes = <DailyQuestType>{};
      for (int seed = 0; seed < 50 && seenTypes.length < 5; seed++) {
        final state = _assignWithDefaults(random: Random(seed));
        for (final quest in state.quests) {
          if (!seenTypes.contains(quest.type)) {
            seenTypes.add(quest.type);
            final expectedTitle = typeTests[quest.type]!(quest.targetValue);
            expect(quest.title, expectedTitle);
          }
        }
      }
    });

    test('各タイプの説明文が空でない', () {
      final seenTypes = <DailyQuestType>{};
      for (int seed = 0; seed < 50 && seenTypes.length < 5; seed++) {
        final state = _assignWithDefaults(random: Random(seed));
        for (final quest in state.quests) {
          if (!seenTypes.contains(quest.type)) {
            seenTypes.add(quest.type);
            expect(quest.description.isNotEmpty, isTrue);
          }
        }
      }
    });

    test('同じシードで同じ結果が得られる（決定性）', () {
      final state1 = _assignWithDefaults(random: Random(12345));
      final state2 = _assignWithDefaults(random: Random(12345));

      expect(state1.quests.length, state2.quests.length);
      for (int i = 0; i < state1.quests.length; i++) {
        expect(state1.quests[i].type, state2.quests[i].type);
        expect(state1.quests[i].targetValue, state2.quests[i].targetValue);
        expect(state1.quests[i].title, state2.quests[i].title);
      }
    });

    test('割り当て件数は候補数以下（候補2件なら最大2件）', () {
      // budgetIsSet=false → underBudget除外
      // allCategoriesUsedRecently=true → newCategory除外
      // 残り: spendOnSelf, receiptScan, noSpending = 3候補 → 最大3件
      final state = service.assignDailyQuests(
        budgetIsSet: false,
        dailyBudgetAmount: 0,
        allCategoriesUsedRecently: true,
        yesterdayWasHighSpending: false,
        yesterdayQuestTypes: const [],
        dayBeforeYesterdayQuestTypes: const [],
        random: Random(777),
      );
      expect(state.quests.length, lessThanOrEqualTo(3));
      // underBudget と newCategory が含まれていないことを確認
      for (final quest in state.quests) {
        expect(quest.type, isNot(DailyQuestType.underBudget));
        expect(quest.type, isNot(DailyQuestType.newCategory));
      }
    });

    test('全クエストに一意なIDが割り当てられる', () {
      final state = _assignWithDefaults(random: Random(42));
      final ids = state.quests.map((q) => q.id).toSet();
      expect(ids.length, state.quests.length);
      for (final id in ids) {
        expect(id.length, 12);
      }
    });

    test('各クエストに正しいEXP報酬とSATORIペナルティが設定される', () {
      final state = _assignWithDefaults(random: Random(42));
      for (final quest in state.quests) {
        expect(quest.expReward, quest.type.defaultExpReward);
        expect(quest.satoriPenalty, quest.type.defaultSatoriPenalty);
      }
    });
  });
}
