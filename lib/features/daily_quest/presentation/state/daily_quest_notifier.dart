import 'package:flutter/foundation.dart';
import 'package:kozuchi/domain/models/daily_quest.dart';
import 'package:kozuchi/features/daily_quest/data/daily_quest_orchestrator.dart';
import 'package:kozuchi/features/daily_quest/data/quest_action.dart';
import 'package:kozuchi/features/daily_quest/data/quest_progress_detector.dart';

/// デイリークエストの状態管理
///
/// [DailyQuestOrchestrator] をラップし、UIに監視可能な状態を提供する。
/// [ChangeNotifier] を継承し、状態変更時にリスナーに通知する。
class DailyQuestNotifier extends ChangeNotifier {
  final DailyQuestOrchestrator _orchestrator;
  final QuestProgressDetector _detector;

  DailyQuestState? _state;
  bool _isLoading = true;
  String? _errorMessage;

  DailyQuestNotifier({
    DailyQuestOrchestrator orchestrator =
        const DailyQuestOrchestrator(),
    QuestProgressDetector detector = const QuestProgressDetector(),
  })  : _orchestrator = orchestrator,
        _detector = detector;

  /// 現在のクエスト状態（未ロード時はnull）
  DailyQuestState? get state => _state;

  /// 読み込み中か
  bool get isLoading => _isLoading;

  /// エラーメッセージ（エラーがない場合はnull）
  String? get errorMessage => _errorMessage;

  /// クエストがあるか
  bool get hasQuests => _state != null && _state!.quests.isNotEmpty;

  /// 全クエスト達成したか
  bool get isAllCompleted =>
      _state != null && _state!.isAllCompleted;

  /// 進行中のクエスト一覧
  List<DailyQuest> get pendingQuests =>
      _state?.pendingQuests ?? [];

  /// 達成済みクエスト一覧
  List<DailyQuest> get completedQuests =>
      _state?.completedQuests ?? [];

  /// 今日のクエストを読み込む（起動時・日跨ぎ時）
  Future<void> loadQuestsForToday({
    required bool budgetIsSet,
    required int dailyBudgetAmount,
    required bool allCategoriesUsedRecently,
    required bool yesterdayWasHighSpending,
    int yesterdayReceiptCount = 0,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _orchestrator.ensureQuestsForToday(
        budgetIsSet: budgetIsSet,
        dailyBudgetAmount: dailyBudgetAmount,
        allCategoriesUsedRecently: allCategoriesUsedRecently,
        yesterdayWasHighSpending: yesterdayWasHighSpending,
        yesterdayReceiptCount: yesterdayReceiptCount,
      );
      _state = result.state;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 保存済みの状態を読み込む（リフレッシュなし）
  Future<void> loadCurrentState() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final saved = await _orchestrator.loadCurrentState();
      _state = saved;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 指定クエストの進捗を更新する
  void updateQuestProgress(String questId, int newProgress) {
    if (_state == null) return;
    final updatedQuests = _state!.quests.map((quest) {
      if (quest.id == questId) {
        return quest.updateProgress(newProgress);
      }
      return quest;
    }).toList();

    _state = DailyQuestState(date: _state!.date, quests: updatedQuests);
    notifyListeners();
  }

  /// ユーザーアクションに基づいてクエスト進捗を自動検出・更新する
  ///
  /// [action] ユーザーの行動（支出記録・レシート撮影・新規カテゴリ使用など）。
  ///
  /// 戻り値: このアクションで新たに達成されたクエストのリスト。
  /// 達成エフェクト表示などに使用する。
  /// 状態が未ロードの場合は空リストを返す。
  List<DailyQuest> detectAction(QuestAction action) {
    if (_state == null) return [];

    final previousQuests = _state!.quests.toList();
    _state = _detector.detectAndUpdate(_state!, action: action);
    notifyListeners();

    // 新たに達成されたクエストを検出
    return _state!.quests.where((quest) {
      if (!quest.isCompleted) return false;
      final previous =
          previousQuests.where((q) => q.id == quest.id).firstOrNull;
      return previous == null || !previous.isCompleted;
    }).toList();
  }

  /// 状態を直接設定する（永続化から復元時など）
  void setState(DailyQuestState state) {
    _state = state;
    _isLoading = false;
    notifyListeners();
  }

  /// 状態を永続化する
  Future<void> persist() async {
    if (_state != null) {
      await _orchestrator.saveState(_state!);
    }
  }

  /// 特定のクエストが達成されたかを検出し、達成済みならそのクエストを返す
  ///
  /// 直前の状態と比較し、新たに達成されたクエストを特定するために使う。
  List<DailyQuest> detectNewlyCompleted(
      List<DailyQuest> previousQuests) {
    if (_state == null) return [];
    return _state!.quests.where((quest) {
      if (!quest.isCompleted) return false;
      final previous =
          previousQuests.where((q) => q.id == quest.id).firstOrNull;
      return previous == null || !previous.isCompleted;
    }).toList();
  }
}
