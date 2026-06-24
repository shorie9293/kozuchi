import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/domain/streak/streak_persistence.dart';
import 'package:kozuchi/domain/streak/streak_state.dart';

/// SharedPreferences を用いたストリーク状態の永続化実装。
///
/// kozuchi の他リポジトリ（PlayerRepository等）と同様に
/// SharedPreferences を使用し、JSON 形式で状態を保存する。
class StreakPersistenceImpl implements StreakPersistence {
  static const String _streakKey = 'kozuchi_streak_state';

  const StreakPersistenceImpl();

  @override
  Future<StreakState?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_streakKey);
    if (jsonString == null) return null;

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return StreakState.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(StreakState state) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(state.toJson());
    await prefs.setString(_streakKey, jsonString);
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_streakKey);
  }
}
