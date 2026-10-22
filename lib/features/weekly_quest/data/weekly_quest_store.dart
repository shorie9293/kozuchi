import 'package:kozuchi/features/weekly_quest/domain/models/weekly_quest_state.dart';

/// 週次クエスト状態の永続化抽象。
///
/// 実装は SharedPreferences（[SharedPreferencesWeeklyQuestStore]）と
/// メモリ内（[InMemoryWeeklyQuestStore]）を切り替え可能。
abstract interface class WeeklyQuestStore {
  /// 保存済み状態を読み出す。未保存・破損時は null。
  Future<WeeklyQuestState?> load();

  /// 状態を保存する。
  Future<void> save(WeeklyQuestState state);

  /// 保存内容を消す。
  Future<void> clear();
}

/// メモリ内実装（試練用）。保存値をそのまま保持する。
class InMemoryWeeklyQuestStore implements WeeklyQuestStore {
  /// 保存内容（試練の検証に使える）。
  WeeklyQuestState? stored;

  @override
  Future<WeeklyQuestState?> load() async => stored;

  @override
  Future<void> save(WeeklyQuestState state) async {
    stored = state;
  }

  @override
  Future<void> clear() async {
    stored = null;
  }
}
