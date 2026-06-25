import 'package:kozuchi/domain/models/daily_quest.dart';
import 'package:kozuchi/features/daily_quest/data/quest_action.dart';

/// クエスト進捗検出器
///
/// ユーザーの行動（支出記録・レシート撮影・新規カテゴリ使用など）を
/// アクティブなデイリークエストの条件と突合し、進捗を更新する。
///
/// このクラスは純粋関数型の設計をとり、外部依存（DB・永続化）を持たない。
/// 必要な情報はすべてパラメータとして注入するため、試験が容易。
///
/// 使用例:
/// ```dart
/// final detector = const QuestProgressDetector();
/// final updatedState = detector.detectAndUpdate(
///   currentState,
///   action: const QuestAction.expenseRecorded(
///     amount: 800,
///     category: '書籍',
///   ),
/// );
/// // updatedState の quests のうち、spendOnSelf が +800 進捗している
/// ```
class QuestProgressDetector {
  const QuestProgressDetector();

  /// アクションに基づいてクエストの進捗を更新する
  ///
  /// [state] 現在のクエスト状態
  /// [action] ユーザーの行動
  ///
  /// 戻り値: 更新されたクエスト状態。
  /// 該当するクエストがない場合は [state] がそのまま返る。
  DailyQuestState detectAndUpdate(
    DailyQuestState state, {
    required QuestAction action,
  }) {
    final updatedQuests = state.quests.map((quest) {
      return _detectAndUpdateQuest(quest, action);
    }).toList();

    return DailyQuestState(date: state.date, quests: updatedQuests);
  }

  /// 単一クエストの進捗を検出・更新する
  DailyQuest _detectAndUpdateQuest(DailyQuest quest, QuestAction action) {
    // 完了済み・失敗済みは更新しない
    if (quest.isCompleted || quest.isFailed) return quest;

    return switch (quest.type) {
      DailyQuestType.spendOnSelf => _handleSpendOnSelf(quest, action),
      DailyQuestType.receiptScan => _handleReceiptScan(quest, action),
      DailyQuestType.newCategory => _handleNewCategory(quest, action),
      DailyQuestType.underBudget => _handleUnderBudget(quest, action),
      DailyQuestType.noSpending => _handleNoSpending(quest, action),
    };
  }

  // ─── タイプ別ハンドラ ──────────────────────────────────

  /// spendOnSelf: 自己投資カテゴリでの支出で進捗
  ///
  /// 自己投資カテゴリ一覧:
  /// 書籍, 趣味, 美容, 教育費, 医療費, 自己啓発, 健康,
  /// フィットネス, 習い事, 教養, アート, 音楽, スポーツ
  DailyQuest _handleSpendOnSelf(DailyQuest quest, QuestAction action) {
    if (action is! ExpenseRecorded) return quest;
    if (!_isSelfCareCategory(action.category)) return quest;

    return quest.updateProgress(quest.currentProgress + action.amount);
  }

  /// receiptScan: レシート撮影で進捗+1
  DailyQuest _handleReceiptScan(DailyQuest quest, QuestAction action) {
    if (action is! ReceiptScanned) return quest;

    return quest.updateProgress(quest.currentProgress + 1);
  }

  /// newCategory: 新カテゴリ使用で進捗+1（一発達成）
  DailyQuest _handleNewCategory(DailyQuest quest, QuestAction action) {
    if (action is! NewCategoryUsed) return quest;

    return quest.updateProgress(quest.currentProgress + 1);
  }

  /// underBudget: 全支出を累積進捗として記録
  ///
  /// 進捗値は累積支出額。予算以内に収まれば成功、超過すれば失敗。
  /// 達成判定は日跨ぎ時のDailyQuestOrchestrator側で行う。
  DailyQuest _handleUnderBudget(DailyQuest quest, QuestAction action) {
    if (action is! ExpenseRecorded) return quest;

    return quest.updateProgress(quest.currentProgress + action.amount);
  }

  /// noSpending: 支出が発生したら即失敗
  DailyQuest _handleNoSpending(DailyQuest quest, QuestAction action) {
    if (action is! ExpenseRecorded) return quest;

    // noSpending は targetValue=0 だが、支出が1円でも発生したら失敗
    return quest.markAsFailed();
  }

  // ─── カテゴリ判定 ──────────────────────────────────────

  /// 自己投資カテゴリかどうかを判定する
  ///
  /// 自分への投資・自己ケアと見なされるカテゴリを判定する。
  /// 部分一致で判定するため、'ビジネス書' のような細分化カテゴリも '書籍' にマッチする。
  bool _isSelfCareCategory(String category) {
    const selfCareCategories = [
      '書籍',
      '趣味',
      '美容',
      '教育費',
      '医療費',
      '自己啓発',
      '健康',
      'フィットネス',
      '習い事',
      '教養',
      'アート',
      '音楽',
      'スポーツ',
      '勉強',
      '学習',
      'スキル',
      'セミナー',
      '講座',
    ];

    return selfCareCategories.any(
      (selfCare) => category.contains(selfCare) || selfCare.contains(category),
    );
  }
}
