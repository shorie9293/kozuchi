import 'package:kozuchi/domain/models/daily_quest.dart';
import 'package:kozuchi/features/daily_quest/data/daily_quest_repository.dart';
import 'package:kozuchi/features/daily_quest/data/quest_assignment_service.dart';

/// デイリークエスト割り当ての統括オーケストレーター
///
/// アプリ起動時や日付跨ぎ時に呼び出され、
/// 1. リフレッシュ要否の判定
/// 2. 前日未達成クエストの失敗処理
/// 3. 新規クエストの割り当て
/// を一貫して実行する。
///
/// このクラスは [DailyQuestRepository] と [QuestAssignmentService] を
/// 束ねる薄い調整層であり、純粋なビジネスロジックは各コンポーネントに委譲する。
class DailyQuestOrchestrator {
  final DailyQuestRepository _repository;
  final QuestAssignmentService _assignmentService;

  const DailyQuestOrchestrator({
    DailyQuestRepository repository = const DailyQuestRepository(),
    QuestAssignmentService assignmentService =
        const QuestAssignmentService(),
  })  : _repository = repository,
        _assignmentService = assignmentService;

  /// 今日のクエスト状態を確保する
  ///
  /// - 保存済み状態が今日のものであればそのまま返す
  /// - 日付跨ぎまたは初回起動の場合は新規割り当てを実行する
  ///
  /// [budgetIsSet] 予算が設定されているか
  /// [dailyBudgetAmount] 日次予算額（[DailyQuestType.underBudget] の目標値）
  /// [allCategoriesUsedRecently] 過去30日間で全支出カテゴリを網羅しているか
  /// [yesterdayWasHighSpending] 前日が高額支出日か
  /// [yesterdayReceiptCount] 前日のレシート撮影枚数（デフォルト0）
  ///
  /// 戻り値 [DailyQuestRefreshResult] には、
  /// - 今日のクエスト状態
  /// - リフレッシュが発生したか
  /// - 前日の失敗クエスト一覧（ペナルティ計算用）
  /// が含まれる。
  Future<DailyQuestRefreshResult> ensureQuestsForToday({
    required bool budgetIsSet,
    required int dailyBudgetAmount,
    required bool allCategoriesUsedRecently,
    required bool yesterdayWasHighSpending,
    int yesterdayReceiptCount = 0,
  }) async {
    // 1. 保存済み状態を確認
    final savedState = await _repository.loadQuests();

    // 2. 今日の日付ならそのまま返す（リフレッシュ不要）
    if (savedState != null && savedState.isToday) {
      return DailyQuestRefreshResult(
        state: savedState,
        didRefresh: false,
        previousDayFailedQuests: const [],
      );
    }

    // 3. 日付跨ぎ処理：前日の未達成クエストを失敗マーク
    final previousDayFailedQuests = <DailyQuest>[];
    if (savedState != null) {
      for (final quest in savedState.quests) {
        if (!quest.isCompleted && !quest.isFailed) {
          previousDayFailedQuests.add(quest.markAsFailed());
        }
      }
    }

    // 4. 前日・前々日のクエストタイプを収集（重複回避用）
    final yesterdayTypes = savedState != null
        ? savedState.quests.map((q) => q.type).toList()
        : <DailyQuestType>[];
    // 前々日は現状の設計では取得できないため空リスト
    const dayBeforeYesterdayTypes = <DailyQuestType>[];

    // 5. 新規クエストを割り当て
    final newState = _assignmentService.assignDailyQuests(
      budgetIsSet: budgetIsSet,
      dailyBudgetAmount: dailyBudgetAmount,
      allCategoriesUsedRecently: allCategoriesUsedRecently,
      yesterdayWasHighSpending: yesterdayWasHighSpending,
      yesterdayQuestTypes: yesterdayTypes,
      dayBeforeYesterdayQuestTypes: dayBeforeYesterdayTypes,
      yesterdayReceiptCount: yesterdayReceiptCount,
    );

    // 6. 保存
    await _repository.saveQuests(newState);

    return DailyQuestRefreshResult(
      state: newState,
      didRefresh: true,
      previousDayFailedQuests: previousDayFailedQuests,
    );
  }

  /// 現在保存されているクエスト状態を読み出す（リフレッシュなし）
  Future<DailyQuestState?> loadCurrentState() async {
    return _repository.loadQuests();
  }

  /// クエスト状態を保存する（進捗更新時など）
  Future<void> saveState(DailyQuestState state) async {
    await _repository.saveQuests(state);
  }

  /// 全データを削除する（リセット用）
  Future<void> clearAll() async {
    await _repository.clearAll();
  }
}

/// [DailyQuestOrchestrator.ensureQuestsForToday] の戻り値
class DailyQuestRefreshResult {
  /// 今日のクエスト状態
  final DailyQuestState state;

  /// 新規割り当てが行われたか
  final bool didRefresh;

  /// 前日未達成で失敗マークされたクエスト一覧
  ///
  /// 呼び出し元はこのリストの [DailyQuestState.totalSatoriPenalty] 相当を
  /// プレイヤーのSATORI値から減算する責務を負う。
  final List<DailyQuest> previousDayFailedQuests;

  const DailyQuestRefreshResult({
    required this.state,
    required this.didRefresh,
    required this.previousDayFailedQuests,
  });

  /// 前日のSATORIペナルティ合計
  int get previousDaySatoriPenalty =>
      previousDayFailedQuests.fold(0, (sum, q) => sum + q.satoriPenalty);
}
