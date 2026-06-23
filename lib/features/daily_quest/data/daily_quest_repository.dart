import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/domain/models/daily_quest.dart';

/// デイリークエスト状態の永続化リポジトリ
///
/// SharedPreferences を使用して日次クエストの状態を保存・復元する。
/// 日付跨ぎの検出機能も提供する。
class DailyQuestRepository {
  static const String _stateKey = 'kozuchi_daily_quests_state';

  const DailyQuestRepository();

  /// 保存済みのデイリークエスト状態を復元する
  ///
  /// 保存データがない場合や破損している場合は null を返す。
  /// 呼び出し側は null の場合に新規クエストを生成すべき。
  Future<DailyQuestState?> loadQuests() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_stateKey);
    if (jsonString == null) return null;

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return DailyQuestState.fromJson(json);
    } catch (_) {
      // 破損データの場合はnullを返す
      return null;
    }
  }

  /// デイリークエスト状態を保存する
  Future<void> saveQuests(DailyQuestState state) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(state.toJson());
    await prefs.setString(_stateKey, jsonString);
  }

  /// リフレッシュが必要か（日付跨ぎが発生しているか）
  ///
  /// 保存された状態の日付が今日と異なる場合は true を返す。
  /// 保存データがない場合も true を返す（新規生成が必要）。
  Future<bool> needsRefresh() async {
    final state = await loadQuests();
    if (state == null) return true;
    return !state.isToday;
  }

  /// 全データを削除する（リセット用）
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_stateKey);
  }
}
