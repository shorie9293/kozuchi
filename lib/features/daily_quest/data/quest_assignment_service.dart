import 'dart:math';

import 'package:kozuchi/domain/models/daily_quest.dart';

/// デイリークエスト割り当てサービス
///
/// 日次クエストの選択・目標値設定・インスタンス生成を統括する。
/// 重み付きランダム抽選により、前日との重複を避けつつ多様なクエストを割り当てる。
///
/// このクラスは純粋関数型の設計をとり、外部依存（DB・永続化）を持たない。
/// 必要な判断材料はすべてパラメータとして注入するため、試験が容易。
class QuestAssignmentService {
  const QuestAssignmentService();

  /// 今日のデイリークエストを割り当てる
  ///
  /// [budgetIsSet] は予算が設定されているか。
  /// [dailyBudgetAmount] は日次予算額（[DailyQuestType.underBudget] の目標値に使用）。
  /// [allCategoriesUsedRecently] は過去30日で全カテゴリを網羅しているか。
  /// [yesterdayWasHighSpending] は前日が高額支出日か。
  /// [yesterdayQuestTypes] は前日に割り当てられたクエストタイプ一覧。
  /// [dayBeforeYesterdayQuestTypes] は前々日に割り当てられたクエストタイプ一覧。
  /// [yesterdayReceiptCount] は前日のレシート撮影枚数。
  /// [random] は乱数生成器（試験用。未指定時はデフォルト）。
  DailyQuestState assignDailyQuests({
    required bool budgetIsSet,
    required int dailyBudgetAmount,
    required bool allCategoriesUsedRecently,
    required bool yesterdayWasHighSpending,
    required List<DailyQuestType> yesterdayQuestTypes,
    required List<DailyQuestType> dayBeforeYesterdayQuestTypes,
    int yesterdayReceiptCount = 0,
    Random? random,
  }) {
    final rng = random ?? Random();

    // Step 1: 全5タイプを候補プールとして開始
    final candidates = DailyQuestType.values.toList();

    // Step 2: ユーザー状態によるフィルタ
    // 予算未設定 → underBudget を除外
    if (!budgetIsSet) {
      candidates.remove(DailyQuestType.underBudget);
    }
    // 30日以内の支出カテゴリが全カテゴリ網羅 → newCategory を除外
    if (allCategoriesUsedRecently) {
      candidates.remove(DailyQuestType.newCategory);
    }

    // 候補がなければ空の状態を返す
    if (candidates.isEmpty) {
      return DailyQuestState.empty();
    }

    // Step 3: 重み計算
    final weights = <DailyQuestType, double>{};
    for (final type in candidates) {
      double weight = 1.0;

      // 前日が高額支出日 → spendOnSelf の重み半減
      if (type == DailyQuestType.spendOnSelf && yesterdayWasHighSpending) {
        weight *= 0.5;
      }

      // 前日に割り当てられたタイプは重み半減
      if (yesterdayQuestTypes.contains(type)) {
        weight *= 0.5;
      }

      // 前々日に割り当てられたタイプは重み微減
      if (dayBeforeYesterdayQuestTypes.contains(type)) {
        weight *= 0.8;
      }

      weights[type] = weight;
    }

    // Step 4: 重み付きランダム抽選で最大3タイプを選択
    final selected = _weightedRandomSelect(weights, 3, rng);

    // Step 5-6: 各タイプに目標値を設定し DailyQuest インスタンスを生成
    final quests = selected.map((type) {
      return _createQuest(
        type,
        dailyBudgetAmount: dailyBudgetAmount,
        yesterdayReceiptCount: yesterdayReceiptCount,
        rng: rng,
      );
    }).toList();

    // Step 7: DailyQuestState に束ねて返却
    return DailyQuestState(quests: quests);
  }

  /// 重み付きランダム抽選
  ///
  /// [weights] から最大 [count] 件を非復元抽出する。
  /// 候補数が [count] 未満の場合は全候補を返す。
  List<DailyQuestType> _weightedRandomSelect(
    Map<DailyQuestType, double> weights,
    int count,
    Random rng,
  ) {
    if (weights.isEmpty) return [];
    // How many we'll actually select
    final actualCount = count.clamp(0, weights.length);
    if (actualCount == 0) return [];

    // Make a mutable copy
    final remaining = Map<DailyQuestType, double>.from(weights);
    final selected = <DailyQuestType>[];

    for (int i = 0; i < actualCount; i++) {
      final totalWeight =
          remaining.values.fold<double>(0.0, (sum, w) => sum + w);
      if (totalWeight <= 0) {
        // All weights zero — pick uniformly among remaining
        final keys = remaining.keys.toList();
        final picked = keys[rng.nextInt(keys.length)];
        selected.add(picked);
        remaining.remove(picked);
        continue;
      }

      double dart = rng.nextDouble() * totalWeight;
      DailyQuestType? picked;
      for (final entry in remaining.entries) {
        dart -= entry.value;
        if (dart <= 0) {
          picked = entry.key;
          break;
        }
      }
      // Fallback (floating point edge case)
      picked ??= remaining.keys.last;

      selected.add(picked);
      remaining.remove(picked);
    }

    return selected;
  }

  /// クエストインスタンスを生成する
  DailyQuest _createQuest(
    DailyQuestType type, {
    required int dailyBudgetAmount,
    required int yesterdayReceiptCount,
    required Random rng,
  }) {
    final targetValue = _determineTargetValue(
      type,
      dailyBudgetAmount: dailyBudgetAmount,
      yesterdayReceiptCount: yesterdayReceiptCount,
      rng: rng,
    );
    final title = _buildTitle(type, targetValue);
    final description = _buildDescription(type, targetValue);

    return DailyQuest(
      type: type,
      title: title,
      description: description,
      targetValue: targetValue,
    );
  }

  /// 目標値を決定する
  int _determineTargetValue(
    DailyQuestType type, {
    required int dailyBudgetAmount,
    required int yesterdayReceiptCount,
    required Random rng,
  }) {
    switch (type) {
      case DailyQuestType.spendOnSelf:
        // 500〜2000円の範囲でランダム
        return 500 + rng.nextInt(1501); // 0..1500 + 500 = 500..2000
      case DailyQuestType.receiptScan:
        // 前日の撮影枚数に応じて段階的に増加（1〜5枚）
        return (yesterdayReceiptCount + 1).clamp(1, 5);
      case DailyQuestType.newCategory:
        return 1; // 固定
      case DailyQuestType.underBudget:
        return dailyBudgetAmount;
      case DailyQuestType.noSpending:
        return 0; // 固定
    }
  }

  /// タイトルを生成する
  String _buildTitle(DailyQuestType type, int targetValue) {
    switch (type) {
      case DailyQuestType.spendOnSelf:
        return '自分に使え：¥$targetValue';
      case DailyQuestType.receiptScan:
        return 'レシートを$targetValue枚撮れ';
      case DailyQuestType.newCategory:
        return '新カテゴリで支出せよ';
      case DailyQuestType.underBudget:
        return '今日は¥$targetValue以内';
      case DailyQuestType.noSpending:
        return '無支出の日';
    }
  }

  /// 説明文を生成する
  String _buildDescription(DailyQuestType type, int targetValue) {
    switch (type) {
      case DailyQuestType.spendOnSelf:
        return '今日は自分のために¥$targetValue使おう。自分への投資は心の栄養';
      case DailyQuestType.receiptScan:
        return '今日のレシートを$targetValue枚撮影しよう。積み重ねが悟りに繋がる';
      case DailyQuestType.newCategory:
        return '最近使っていないカテゴリで支出しよう。新しい使い道を開拓せよ';
      case DailyQuestType.underBudget:
        return '今日の支出を¥$targetValue以内に抑えよう。節制こそが修行';
      case DailyQuestType.noSpending:
        return '今日は1円も使わない日。無駄な支出を見直す機会とせよ';
    }
  }
}
