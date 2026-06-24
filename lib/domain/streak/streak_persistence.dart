import 'streak_state.dart';

/// ストリーク状態の永続化インターフェース。
///
/// 実装は Hive / SharedPreferences / SQLite / ファイル など任意。
/// [StreakRepository] がこのインターフェースを通じて状態を読み書きする。
abstract class StreakPersistence {
  /// 保存済みのストリーク状態を読み込む。
  /// 未保存の場合は `null` を返す。
  Future<StreakState?> load();

  /// ストリーク状態を保存する。
  Future<void> save(StreakState state);

  /// 保存済みのストリーク状態を削除する。
  Future<void> clear();
}
