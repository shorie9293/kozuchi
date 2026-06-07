import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/domain/models/player_model.dart';
import 'package:kozuchi/domain/models/trial_quest.dart';

/// プレイヤー状態の永続化リポジトリ
///
/// SharedPreferences を使用してプレイヤーモデルと現在の試練を保存・復元する。
/// アプリ再起動時にもゲーム進行が失われないようにする。
class PlayerRepository {
  static const String _playerKey = 'kozuchi_player_state';
  static const String _questKey = 'kozuchi_current_quest';

  const PlayerRepository();

  /// 保存済みのプレイヤー状態を復元する
  ///
  /// 保存データがない場合は null を返す。
  /// 呼び出し側は null の場合にデフォルトプレイヤーを使用すべき。
  Future<PlayerModel?> loadPlayer() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_playerKey);
    if (jsonString == null) return null;

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return PlayerModel.fromJson(json);
    } catch (_) {
      // 破損データは無視してデフォルトにフォールバック
      return null;
    }
  }

  /// プレイヤー状態を保存する
  Future<void> savePlayer(PlayerModel player) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(player.toJson());
    await prefs.setString(_playerKey, jsonString);
  }

  /// 保存済みの現在の試練を復元する
  ///
  /// 保存データがない場合は null を返す。
  Future<TrialQuest?> loadQuest() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_questKey);
    if (jsonString == null) return null;

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return TrialQuest.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// 現在の試練を保存する
  Future<void> saveQuest(TrialQuest quest) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(quest.toJson());
    await prefs.setString(_questKey, jsonString);
  }

  /// 全データを削除する（リセット用）
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_playerKey);
    await prefs.remove(_questKey);
  }
}
