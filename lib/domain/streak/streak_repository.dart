import 'package:kozuchi/domain/streak/streak_persistence.dart';
import 'package:kozuchi/domain/streak/streak_state.dart';
import 'package:kozuchi/domain/streak/streak_tracker.dart';

/// ストリーク追跡と永続化を橋渡しするリポジトリ。
///
/// [StreakTracker] のロジックと [StreakPersistence] による保存を統合し、
/// `recordActivity` のたびに自動的に状態を永続化する。
class StreakRepository {
  final StreakPersistence _persistence;
  StreakTracker _tracker;

  /// [persistence] を通じて状態を読み書きするリポジトリを生成する。
  ///
  /// 生成直後は空のトラッカーが設定される。
  /// 保存済みの状態を復元するには [loadOrCreate] を呼ぶこと。
  StreakRepository({required StreakPersistence persistence})
      : _persistence = persistence,
        _tracker = StreakTracker(state: StreakState.empty());

  /// 内部の [StreakTracker] を返す。
  StreakTracker get tracker => _tracker;

  /// 保存済みの状態からトラッカーを復元する。
  /// 未保存の場合は空のトラッカーを返す。
  Future<StreakTracker> loadOrCreate() async {
    final saved = await _persistence.load();
    _tracker = StreakTracker(state: saved ?? StreakState.empty());
    return _tracker;
  }

  /// 活動を記録し、ストリーク状態を更新して永続化する。
  ///
  /// [now] は活動日時。時刻部分は無視され、日付のみで判定される。
  /// 戻り値は更新後の [StreakState]。
  Future<StreakState> recordActivity(DateTime now) async {
    final newState = _tracker.recordActivity(now);
    await _persistence.save(newState);
    return newState;
  }
}
