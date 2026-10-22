import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:kozuchi/features/weekly_quest/data/weekly_quest_store.dart';
import 'package:kozuchi/features/weekly_quest/domain/models/weekly_quest_state.dart';

/// SharedPreferences 実装。key は [storageKey]、値は JSON 文字列。
///
/// 読み出しは「未保存・空・JSON 破損・型不一致」のすべてで null を返し、
/// 例外を外へ漏らさない（アプリを落とさない）。
class SharedPreferencesWeeklyQuestStore implements WeeklyQuestStore {
  /// 永続化キー。
  static const String storageKey = 'weekly_quest_state_v1';

  const SharedPreferencesWeeklyQuestStore();

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  @override
  Future<WeeklyQuestState?> load() async {
    try {
      final prefs = await _prefs();
      final raw = prefs.getString(storageKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return WeeklyQuestState.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      // JSON 破損・型不一致（getString が投げた場合を含む）は null へ倒す。
      return null;
    }
  }

  @override
  Future<void> save(WeeklyQuestState state) async {
    final prefs = await _prefs();
    await prefs.setString(storageKey, jsonEncode(state.toJson()));
  }

  @override
  Future<void> clear() async {
    final prefs = await _prefs();
    await prefs.remove(storageKey);
  }
}
