import 'dart:math';

import 'package:kozuchi/domain/services/expense_repository.dart';
import 'package:kozuchi/features/weekly_quest/data/quest_templates.dart';
import 'package:kozuchi/features/weekly_quest/domain/models/weekly_quest.dart';

/// 週間クエスト生成器
///
/// ユーザーの支出履歴を分析し、カテゴリ別の支出制限チャレンジを
/// 3〜5件自動生成する。毎週月曜に呼び出されることを想定。
///
/// ## 生成アルゴリズム
///
/// 1. 直近4週間の支出データを取得
/// 2. カテゴリ別に週平均支出を算出
/// 3. 前期間との比較で支出増加カテゴリを優先
/// 4. テンプレートを選択しクエストを生成（バリエーション確保）
/// 5. 難易度（easy/medium/hard）を自動判定
///
/// ## 使用例
/// ```dart
/// final generator = WeeklyQuestGenerator(repository);
/// final quests = await generator.generate(DateTime.now());
/// // → 3〜5件の WeeklyQuest が返る
/// ```
class WeeklyQuestGenerator {
  final ExpenseRepository _repository;

  /// 分析対象とする週数（デフォルト4週）
  final int analysisWeeks;

  /// 乱数シード（テスト再現性用。nullの場合はランダム）
  final int? randomSeed;

  WeeklyQuestGenerator(
    this._repository, {
    this.analysisWeeks = 4,
    this.randomSeed,
  });

  // ============================================================
  //  公開API
  // ============================================================

  /// 指定された週（月曜始まり）のクエストを3〜5件生成する
  ///
  /// [weekStart] は月曜日であるべき。月曜以外が渡された場合は
  /// その週の月曜に正規化される。
  ///
  /// 返値は3〜5件の [WeeklyQuest]。支出データが不十分な場合は
  /// 固定テンプレートで最低3件を返す。
  Future<List<WeeklyQuest>> generate(DateTime weekStart) async {
    final monday = _toMonday(weekStart);
    final rng = Random(randomSeed ?? DateTime.now().millisecondsSinceEpoch);

    // 1. 過去N週間の支出データを取得
    final categoryAvgs = await _calculateCategoryAverages(monday);

    // 2. クエスト生成対象カテゴリを選択（最大5件）
    final selectedCategories =
        _selectTargetCategories(categoryAvgs, rng, count: 5);

    // 3. 各カテゴリに対してクエストを生成
    final quests = <WeeklyQuest>[];
    final usedTemplateIds = <String>{}; // 同一週での重複回避

    for (final cat in selectedCategories) {
      final avgSpend = categoryAvgs[cat] ?? 1000;

      // テンプレート選択（重複回避）
      final templateTypes = recommendedTemplateTypes(cat, avgSpend);
      final availableTypes = templateTypes
          .where((t) => !usedTemplateIds.contains(t.name))
          .toList();
      if (availableTypes.isEmpty) continue;

      final templateType =
          availableTypes[rng.nextInt(availableTypes.length)];
      usedTemplateIds.add(templateType.name);

      final template = QuestTemplate.byId[templateType.name]!;

      // 難易度に応じた削減率を決定
      final difficulty = _selectDifficulty(rng);
      final reductionRate = _reductionRateFor(difficulty, rng);

      // 予算上限を計算
      final budgetLimit =
          template.budgetCalculator(cat, avgSpend, reductionRate);

      // 追加パラメータ（テンプレート別）
      final param2 = _calcParam2(templateType, avgSpend, budgetLimit, rng);

      // 削減率の実値で難易度を再計算
      final actualReductionPercent =
          avgSpend > 0 ? ((avgSpend - budgetLimit) / avgSpend * 100) : 0.0;
      final actualDifficulty =
          QuestDifficulty.fromReductionPercent(actualReductionPercent);

      final quest = WeeklyQuest(
        id: _generateId(),
        title: template.titleBuilder(cat, budgetLimit, param2),
        description: template.descriptionBuilder(
            cat, budgetLimit, avgSpend, param2),
        targetCategory: cat,
        budgetLimit: budgetLimit,
        currentAvgSpend: avgSpend,
        difficulty: actualDifficulty,
        generatedAt: DateTime.now(),
        weekStart: monday,
        templateId: templateType.name,
      );

      quests.add(quest);
    }

    // 4. 最低3件確保（データ不足時のフォールバック）
    if (quests.length < 3) {
      quests.addAll(_generateFallbackQuests(monday, 3 - quests.length, rng));
    }

    // 最大5件に制限
    return quests.take(5).toList();
  }

  // ============================================================
  //  内部ロジック
  // ============================================================

  /// カテゴリ別の週平均支出を算出
  ///
  /// 戻り値: { '食費': 8500, '娯楽': 12000, '総支出': 45000, ... }
  Future<Map<String, int>> _calculateCategoryAverages(
      DateTime weekStart) async {
    final endDate = weekStart.subtract(const Duration(days: 1));
    final startDate =
        endDate.subtract(Duration(days: 7 * analysisWeeks - 1));

    final entries = await _repository.getEntries(
      start: startDate,
      end: endDate,
    );

    if (entries.isEmpty) return {};

    // カテゴリ別に総額を集計
    final categoryTotals = <String, int>{};
    for (final entry in entries) {
      categoryTotals[entry.category] =
          (categoryTotals[entry.category] ?? 0) + entry.amount;
    }

    // 週平均に変換
    final averages = <String, int>{};
    var grandTotal = 0;
    for (final entry in categoryTotals.entries) {
      final avg = (entry.value / analysisWeeks).round();
      averages[entry.key] = avg;
      grandTotal += entry.value;
    }
    averages['総支出'] = (grandTotal / analysisWeeks).round();

    return averages;
  }

  /// クエスト生成対象カテゴリを選択（最大 [count] 件）
  ///
  /// 選択基準:
  /// 1. 支出額が大きいカテゴリを優先
  /// 2. 「総支出」は常に候補（ただしカテゴリクエストとは別枠）
  List<String> _selectTargetCategories(
    Map<String, int> averages,
    Random rng, {
    required int count,
  }) {
    if (averages.isEmpty) return [];

    final categoryEntries = averages.entries
        .where((e) => e.key != '総支出')
        .toList();

    if (categoryEntries.isEmpty) return [];

    // 支出額降順でソート
    categoryEntries.sort((a, b) => b.value.compareTo(a.value));

    // 上位から選択（少しランダム性を加える）
    final selected = <String>[];
    final shuffled = [...categoryEntries]..shuffle(rng);

    // まず上位3件を優先的に選ぶ
    for (final entry in categoryEntries.take(3)) {
      if (selected.length >= count - 1) break;
      if (!selected.contains(entry.key)) {
        selected.add(entry.key);
      }
    }

    // 残りをランダムに補充
    for (final entry in shuffled) {
      if (selected.length >= count - 1) break;
      if (!selected.contains(entry.key)) {
        selected.add(entry.key);
      }
    }

    // '総支出' は最後に追加（毎回入れるかランダム）
    if (averages.containsKey('総支出') && rng.nextDouble() < 0.7) {
      selected.add('総支出');
    }

    return selected;
  }

  /// ランダムに難易度を選択（easy: 30%, medium: 50%, hard: 20%）
  QuestDifficulty _selectDifficulty(Random rng) {
    final roll = rng.nextDouble();
    if (roll < 0.30) return QuestDifficulty.easy;
    if (roll < 0.80) return QuestDifficulty.medium;
    return QuestDifficulty.hard;
  }

  /// 難易度に応じた削減率（%）を返す（ばらつきあり）
  double _reductionRateFor(QuestDifficulty difficulty, Random rng) {
    switch (difficulty) {
      case QuestDifficulty.easy:
        return 5.0 + rng.nextDouble() * 10.0; // 5〜15%
      case QuestDifficulty.medium:
        return 15.0 + rng.nextDouble() * 10.0; // 15〜25%
      case QuestDifficulty.hard:
        return 25.0 + rng.nextDouble() * 10.0; // 25〜35%
    }
  }

  /// テンプレート別の追加パラメータを計算
  int _calcParam2(QuestTemplateType type, int avg, int limit, Random rng) {
    switch (type) {
      case QuestTemplateType.frequencyReduce:
        // 1回あたりの想定額から回数を逆算
        final perTransaction = max(300, (avg / 7).round());
        return max(1, (limit / perTransaction).round());
      case QuestTemplateType.comparePrevious:
        // 削減率を整数で
        return avg > 0 ? ((avg - limit) / avg * 100).round() : 10;
      case QuestTemplateType.noSpendDay:
        // 1〜3日の無支出デー
        return 1 + rng.nextInt(3);
      default:
        return 0;
    }
  }

  /// 固定テンプレートからフォールバッククエストを生成（データ不足時）
  List<WeeklyQuest> _generateFallbackQuests(
      DateTime monday, int count, Random rng) {
    final fallbacks = [
      () => WeeklyQuest(
            id: _generateId(),
            title: '今週は食費を¥10,000以内に',
            description: '自炊を心がけ、外食を控えめに。'
                '手作りの食事は心も満たす。',
            targetCategory: '食費',
            budgetLimit: 10000,
            currentAvgSpend: 12000,
            difficulty: QuestDifficulty.easy,
            generatedAt: DateTime.now(),
            weekStart: monday,
            templateId: QuestTemplateType.budgetLimit.name,
          ),
      () => WeeklyQuest(
            id: _generateId(),
            title: '今週は娯楽費を¥5,000以内に',
            description: '図書館や公園など、お金をかけない'
                '楽しみ方を見つけてみよう。',
            targetCategory: '娯楽',
            budgetLimit: 5000,
            currentAvgSpend: 8000,
            difficulty: QuestDifficulty.medium,
            generatedAt: DateTime.now(),
            weekStart: monday,
            templateId: QuestTemplateType.budgetLimit.name,
          ),
      () => WeeklyQuest(
            id: _generateId(),
            title: '今週の総支出を¥30,000以内に',
            description: '全カテゴリで少しずつ意識しよう。'
                'レシートを見返す習慣をつけるのが近道。',
            targetCategory: '総支出',
            budgetLimit: 30000,
            currentAvgSpend: 40000,
            difficulty: QuestDifficulty.hard,
            generatedAt: DateTime.now(),
            weekStart: monday,
            templateId: QuestTemplateType.totalCap.name,
          ),
      () => WeeklyQuest(
            id: _generateId(),
            title: '今週は交際費を¥8,000以内に',
            description: '人付き合いも大切だが、無理のない範囲で。'
                'お茶や散歩で十分なことも多い。',
            targetCategory: '交際費',
            budgetLimit: 8000,
            currentAvgSpend: 10000,
            difficulty: QuestDifficulty.easy,
            generatedAt: DateTime.now(),
            weekStart: monday,
            templateId: QuestTemplateType.budgetLimit.name,
          ),
      () => WeeklyQuest(
            id: _generateId(),
            title: '今週は交通費を¥3,000以内に',
            description: 'できる範囲で徒歩や自転車に切り替えて。'
                '健康にも良い一石二鳥の挑戦だ。',
            targetCategory: '交通費',
            budgetLimit: 3000,
            currentAvgSpend: 5000,
            difficulty: QuestDifficulty.medium,
            generatedAt: DateTime.now(),
            weekStart: monday,
            templateId: QuestTemplateType.frequencyReduce.name,
          ),
    ];

    // ランダムに選択（重複なし）
    final indices = List.generate(fallbacks.length, (i) => i)..shuffle(rng);
    final result = <WeeklyQuest>[];
    for (final i in indices.take(count)) {
      result.add(fallbacks[i]());
    }
    return result;
  }

  // ============================================================
  //  ユーティリティ
  // ============================================================

  /// 月曜日に正規化
  DateTime _toMonday(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  /// 簡易UUID生成（ユニークID用）
  String _generateId() {
    final rng = Random(DateTime.now().microsecondsSinceEpoch);
    final chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(12, (_) => chars[rng.nextInt(chars.length)]).join();
  }
}
