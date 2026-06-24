import 'package:kozuchi/domain/streak/streak_event.dart';
import 'package:kozuchi/domain/streak/streak_state.dart';

/// ストリーク追跡の中核ロジック。
///
/// 日次の活動記録を受け取り、ストリークの増加・継続・途絶を判定し、
/// コールバックでイベントを通知する。
class StreakTracker {
  StreakState _state;

  /// ストリークイベント発生時に呼ばれるコールバック。
  ///
  /// 第一引数にイベント種別、第二引数に更新後の [StreakState] が渡される。
  void Function(StreakEvent event, StreakState state)? onStreakEvent;

  /// [state] を初期状態としてトラッカーを生成する。
  StreakTracker({StreakState? state}) : _state = state ?? StreakState.empty();

  /// 現在のストリーク状態を返す。
  StreakState get currentState => _state;

  /// 指定された日付に活動があったことを記録し、ストリーク状態を更新する。
  ///
  /// [now] は活動日として扱われる。時刻部分は無視され、日付のみで判定する。
  /// 戻り値は更新後の [StreakState]。
  StreakState recordActivity(DateTime now) {
    final today = _dateOnly(now);
    final lastDate = _state.lastActivityDate;

    // 初回：ストリーク開始
    if (lastDate == null) {
      _state = _state.copyWith(
        streakDays: 1,
        longestStreak: _updateLongestStreak(1),
        lastActivityDate: today,
      );
      onStreakEvent?.call(StreakEvent.started, _state);
      return _state;
    }

    final lastDay = _dateOnly(lastDate);
    final diffDays = today.difference(lastDay).inDays;

    // 同日：変更なし（最終活動時刻は更新）
    if (diffDays == 0) {
      _state = _state.copyWith(lastActivityDate: now);
      return _state;
    }

    // 連続日（翌日）：ストリーク継続
    if (diffDays == 1) {
      final newStreak = _state.streakDays + 1;
      _state = _state.copyWith(
        streakDays: newStreak,
        longestStreak: _updateLongestStreak(newStreak),
        lastActivityDate: today,
      );
      onStreakEvent?.call(StreakEvent.continued, _state);
      return _state;
    }

    // 1日以上空いた：ストリーク途絶 → リセットして新ストリーク開始
    _state = _state.copyWith(
      streakDays: 1,
      longestStreak: _updateLongestStreak(0),
      lastActivityDate: today,
    );
    onStreakEvent?.call(StreakEvent.broken, _state);
    return _state;
  }

  /// 最長記録を更新する。
  /// [candidate] が既存の longestStreak を超えていれば candidate を返す。
  int _updateLongestStreak(int candidate) {
    return candidate > _state.longestStreak ? candidate : _state.longestStreak;
  }

  /// 時刻を切り捨てて日付のみの DateTime を返す。
  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}
