import 'package:flutter/foundation.dart';

/// 前面復帰時に観測された暦日の変化。
enum DayRolloverResult {
  /// 端末ローカル暦日が変わっていない。
  sameDay,

  /// ローカル暦日が翌日以降へ進んだ。
  rolledOver,

  /// ローカル暦日が過去へ巻き戻った（端末時計の変更など）。
  clockWentBack,
}

/// ローカル暦日（年/月/日）の跨ぎを検出する純粋ロジック。
///
/// - 判定は必ず端末ローカルの [DateTime] で行う（UTC を混ぜない）。
/// - 巻き戻し時は例外を投げず、[lastSeen] を据え置いてクランプする。
class DayRolloverDetector {
  DayRolloverDetector({required DateTime lastSeen}) : _lastSeen = lastSeen;

  DateTime _lastSeen;

  /// 最後に観測した日時（判定の基準）。
  DateTime get lastSeen => _lastSeen;

  /// [now] を観測し、暦日が変化したかを返す。
  ///
  /// - 同一暦日 → [DayRolloverResult.sameDay]（lastSeen を now に更新）
  /// - 暦日が進んだ → [DayRolloverResult.rolledOver]（lastSeen を now に更新）
  /// - 暦日が巻き戻った → [DayRolloverResult.clockWentBack]（lastSeen 据え置き）
  DayRolloverResult check(DateTime now) {
    final lastDay = _dayOf(_lastSeen);
    final currentDay = _dayOf(now);

    if (currentDay == lastDay) {
      _lastSeen = now;
      return DayRolloverResult.sameDay;
    }

    if (now.isAfter(_lastSeen)) {
      _lastSeen = now;
      return DayRolloverResult.rolledOver;
    }

    // 暦日が過去へ巻き戻った。lastSeen は据え置く（クランプ）。
    debugPrint(
      '[kozuchi] ⚠️ 端末時計の巻き戻しを検出: lastSeen=$_lastSeen / now=$now',
    );
    return DayRolloverResult.clockWentBack;
  }

  /// ローカル暦日を年月日のタプルで取り出す。
  (int, int, int) _dayOf(DateTime value) {
    final local = value.toLocal();
    return (local.year, local.month, local.day);
  }
}
