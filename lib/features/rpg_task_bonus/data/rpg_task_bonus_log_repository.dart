import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// rpg-task敵討伐ボーナスのログ管理リポジトリ
///
/// SharedPreferences を使用して日次ボーナス回数と履歴を保存・復元する。
/// 1日3回の上限管理と、過去のボーナス履歴の参照を提供する。
///
/// SharedPreferences 上のキー構造:
/// - rpg_bonus_daily_count_YYYY-MM-DD: その日のボーナス付与回数
/// - rpg_bonus_log: ボーナス履歴のJSONリスト（最新10件保持）
class RpgTaskBonusLogRepository {
  static const String _dailyCountPrefix = 'rpg_bonus_daily_count_';
  static const String _logKey = 'rpg_bonus_log';
  static const int _maxLogEntries = 10;

  const RpgTaskBonusLogRepository();

  /// 現在の日付キーを返す（UTC基準）
  String _todayKey() {
    final now = DateTime.now().toUtc();
    return '$_dailyCountPrefix${now.year}-${_monthPad(now.month)}-${_dayPad(now.day)}';
  }

  String _monthPad(int m) => m.toString().padLeft(2, '0');
  String _dayPad(int d) => d.toString().padLeft(2, '0');

  /// 本日のボーナス付与回数を取得する
  Future<int> getTodayCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_todayKey()) ?? 0;
  }

  /// ボーナス付与を記録する（日次カウント +1、ログに追加）
  Future<void> recordBonus({
    required String taskTitle,
    required String questRank,
    required int bonusExp,
    required int baseExp,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // 日次カウントをインクリメント
    final todayKey = _todayKey();
    final currentCount = prefs.getInt(todayKey) ?? 0;
    await prefs.setInt(todayKey, currentCount + 1);

    // ログに追加
    final logEntry = {
      'taskTitle': taskTitle,
      'questRank': questRank,
      'bonusExp': bonusExp,
      'baseExp': baseExp,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };

    final logJson = prefs.getString(_logKey);
    final List<dynamic> logList =
        logJson != null ? (jsonDecode(logJson) as List<dynamic>) : [];

    logList.insert(0, logEntry); // 最新を先頭に

    // 最大件数を超えたら古いものを削除
    if (logList.length > _maxLogEntries) {
      logList.removeRange(_maxLogEntries, logList.length);
    }

    await prefs.setString(_logKey, jsonEncode(logList));
  }

  /// ボーナス履歴を取得する（最新順）
  Future<List<Map<String, dynamic>>> getLog() async {
    final prefs = await SharedPreferences.getInstance();
    final logJson = prefs.getString(_logKey);
    if (logJson == null) return [];

    try {
      final list = jsonDecode(logJson) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// 本日の残りボーナス回数を返す
  Future<int> getRemainingBonusesToday({int maxDaily = 3}) async {
    final count = await getTodayCount();
    final remaining = maxDaily - count;
    return remaining < 0 ? 0 : remaining;
  }

  /// 全データを削除する（リセット用）
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    // 日次カウントはキーが日付依存なので全削除は難しい → ログのみ削除
    await prefs.remove(_logKey);
  }
}
