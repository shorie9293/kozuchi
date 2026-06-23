import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/domain/models/goal.dart';
import 'package:kozuchi/domain/models/achievement.dart';

/// 目標データの永続化リポジトリ
///
/// SharedPreferences を使用して目標一覧・称号一覧を保存・復元する。
///
/// ## データベーススキーマ（論理定義）
///
/// SharedPreferences 上のキー構造:
/// - `kozuchi_goal_schema_version` : スキーマバージョン番号（int）
/// - `kozuchi_goals` : 全目標のJSON配列
/// - `kozuchi_achievements` : 全称号のJSON配列
///
/// ### goals テーブル相当 (List<Goal> in JSON)
/// | カラム | 型 | 制約 | 説明 |
/// |--------|-----|------|------|
/// | id | TEXT | PK | UUID v4 |
/// | userId | TEXT | NOT NULL DEFAULT 'default' | ユーザー識別子 |
/// | title | TEXT | NOT NULL | 目標名 |
/// | targetAmount | INTEGER | NOT NULL DEFAULT 0 | 目標金額（円） |
/// | deadline | TEXT | NULLABLE | ISO 8601 期限日時 |
/// | currentAmount | INTEGER | NOT NULL DEFAULT 0 | 現在の達成額 |
/// | status | TEXT | NOT NULL DEFAULT 'active' | active / completed |
/// | createdAt | TEXT | NOT NULL | ISO 8601 作成日時 |
/// | updatedAt | TEXT | NOT NULL | ISO 8601 更新日時 |
///
/// ### achievements テーブル相当 (List<Achievement> in JSON)
/// | カラム | 型 | 制約 | 説明 |
/// |--------|-----|------|------|
/// | id | TEXT | PK | 一意識別子 |
/// | title | TEXT | NOT NULL | 称号名 |
/// | description | TEXT | NOT NULL | 称号の説明 |
/// | earnedAt | TEXT | NOT NULL | ISO 8601 獲得日時 |
/// | goalId | TEXT | NULLABLE FK→goals.id | 紐づく目標ID |
///
/// ## マイグレーション
///
/// スキーマバージョン番号で管理。将来のバージョン追加時は
/// `_migrate()` メソッドにケースを追加すること。
class GoalRepository {
  static const String _schemaVersionKey = 'kozuchi_goal_schema_version';
  static const String _goalsKey = 'kozuchi_goals';
  static const String _achievementsKey = 'kozuchi_achievements';

  /// 現在のスキーマバージョン
  static const int currentSchemaVersion = 1;

  const GoalRepository();

  /// スキーマの初期化とマイグレーションを実行する
  ///
  /// アプリ起動時に一度だけ呼び出すこと。
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final storedVersion = prefs.getInt(_schemaVersionKey) ?? 0;

    if (storedVersion < currentSchemaVersion) {
      await _migrate(prefs, storedVersion, currentSchemaVersion);
      await prefs.setInt(_schemaVersionKey, currentSchemaVersion);
    }
  }

  /// マイグレーション処理
  ///
  /// v0 → v1: 初回。キー構造を確立。
  Future<void> _migrate(
    SharedPreferences prefs,
    int fromVersion,
    int toVersion,
  ) async {
    for (int v = fromVersion + 1; v <= toVersion; v++) {
      switch (v) {
        case 1:
          // v0 → v1: 初期スキーマ確立
          // 既存データがない場合は空リストで初期化
          if (!prefs.containsKey(_goalsKey)) {
            await prefs.setString(_goalsKey, '[]');
          }
          if (!prefs.containsKey(_achievementsKey)) {
            await prefs.setString(_achievementsKey, '[]');
          }
          break;
        // 将来のマイグレーション:
        // case 2:
        //   // v1 → v2: 新フィールド追加など
        //   break;
      }
    }
  }

  // ─── Goal CRUD ────────────────────────────────────────────

  /// 全目標を取得する
  ///
  /// 作成日時の降順（新しい順）で返す。
  Future<List<Goal>> getAllGoals() async {
    final goals = await _loadGoals();
    goals.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return goals;
  }

  /// アクティブな目標のみを取得する
  Future<List<Goal>> getActiveGoals() async {
    final goals = await _loadGoals();
    return goals.where((g) => g.status == GoalStatus.active).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// 完了した目標のみを取得する
  Future<List<Goal>> getCompletedGoals() async {
    final goals = await _loadGoals();
    return goals.where((g) => g.status == GoalStatus.completed).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  /// IDで目標を検索する
  Future<Goal?> getGoalById(String id) async {
    final goals = await _loadGoals();
    try {
      return goals.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 目標を新規作成する
  ///
  /// 作成後、id を含む完全な Goal を返す。
  Future<Goal> createGoal(Goal goal) async {
    final goals = await _loadGoals();
    goals.add(goal);
    await _saveGoals(goals);
    return goal;
  }

  /// 目標を更新する
  ///
  /// 指定された id の目標を上書きする。存在しない場合は何もしない。
  Future<void> updateGoal(Goal updatedGoal) async {
    final goals = await _loadGoals();
    final index = goals.indexWhere((g) => g.id == updatedGoal.id);
    if (index != -1) {
      goals[index] = updatedGoal;
      await _saveGoals(goals);
    }
  }

  /// 目標の進捗を更新する
  ///
  /// 目標額に達した場合は自動的に completed になり、称号が生成される。
  /// 戻り値: 生成された称号（達成時のみ）。非達成時は null。
  Future<Achievement?> updateGoalProgress(String goalId, int newAmount) async {
    final goals = await _loadGoals();
    final index = goals.indexWhere((g) => g.id == goalId);
    if (index == -1) return null;

    final updated = goals[index].updateProgress(newAmount);
    goals[index] = updated;
    await _saveGoals(goals);

    // 達成時に称号を生成
    if (updated.status == GoalStatus.completed) {
      final achievement = updated.generateAchievement();
      if (achievement != null) {
        await addAchievement(achievement);
        return achievement;
      }
    }
    return null;
  }

  /// 目標を削除する
  Future<void> deleteGoal(String id) async {
    final goals = await _loadGoals();
    goals.removeWhere((g) => g.id == id);
    await _saveGoals(goals);
  }

  /// 全目標を削除する（リセット用）
  Future<void> deleteAllGoals() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_goalsKey, '[]');
  }

  // ─── Achievement CRUD ─────────────────────────────────────

  /// 全称号を取得する
  ///
  /// 獲得日時の降順（新しい順）で返す。
  Future<List<Achievement>> getAllAchievements() async {
    final achievements = await _loadAchievements();
    achievements.sort((a, b) => b.earnedAt.compareTo(a.earnedAt));
    return achievements;
  }

  /// 指定した目標に紐づく称号を取得する
  Future<List<Achievement>> getAchievementsForGoal(String goalId) async {
    final achievements = await _loadAchievements();
    return achievements
        .where((a) => a.goalId == goalId)
        .toList()
      ..sort((a, b) => b.earnedAt.compareTo(a.earnedAt));
  }

  /// 称号を追加する
  Future<void> addAchievement(Achievement achievement) async {
    final achievements = await _loadAchievements();
    achievements.add(achievement);
    await _saveAchievements(achievements);
  }

  /// 全称号を削除する（リセット用）
  Future<void> deleteAllAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_achievementsKey, '[]');
  }

  // ─── 内部ヘルパー ────────────────────────────────────────

  /// 目標リストを SharedPreferences から読み込む
  Future<List<Goal>> _loadGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_goalsKey);
    if (jsonString == null || jsonString.isEmpty) return [];

    try {
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((e) => Goal.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// 目標リストを SharedPreferences に保存する
  Future<void> _saveGoals(List<Goal> goals) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString =
        jsonEncode(goals.map((g) => g.toJson()).toList());
    await prefs.setString(_goalsKey, jsonString);
  }

  /// 称号リストを SharedPreferences から読み込む
  Future<List<Achievement>> _loadAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_achievementsKey);
    if (jsonString == null || jsonString.isEmpty) return [];

    try {
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((e) => Achievement.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// 称号リストを SharedPreferences に保存する
  Future<void> _saveAchievements(List<Achievement> achievements) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString =
        jsonEncode(achievements.map((a) => a.toJson()).toList());
    await prefs.setString(_achievementsKey, jsonString);
  }
}
