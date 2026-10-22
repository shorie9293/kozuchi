import 'package:kozuchi/features/weekly_quest/data/weekly_quest_repository.dart';
import 'package:kozuchi/features/weekly_quest/domain/models/active_weekly_quest.dart';
import 'package:kozuchi/features/weekly_quest/presentation/state/weekly_quest_notifier.dart';

/// [WeeklyQuestNotifier] を [WeeklyQuestRepository] として見せるアダプタ。
///
/// 既存の [WeeklyQuestSelectionScreen] はリポジトリ経由で候補取得・選択を行う。
/// 本アダプタを挟むことで、画面側を変更せずに notifier の状態を単一の
/// 真実の源にできる。
///
/// `userId` はローカル単一ユーザー前提のため無視する（全メソッド共通）。
class NotifierWeeklyQuestRepository implements WeeklyQuestRepository {
  NotifierWeeklyQuestRepository(this._notifier);

  final WeeklyQuestNotifier _notifier;

  /// 候補を pending 状態の [ActiveWeeklyQuest] に包んで返す。
  @override
  Future<List<ActiveWeeklyQuest>> getPendingQuests(String userId) async {
    return _notifier.pendingQuests
        .map((quest) => ActiveWeeklyQuest(
              quest: quest,
              status: WeeklyQuestStatus.pending,
            ))
        .toList();
  }

  /// 選択を notifier に委譲する。
  @override
  Future<void> selectQuest(String userId, String questId) async {
    await _notifier.selectQuest(questId);
  }

  /// 選択中のクエストを返す（未選択なら null）。
  @override
  Future<ActiveWeeklyQuest?> getActiveQuest(String userId) async =>
      _notifier.activeQuest;
}
