import 'package:kozuchi/features/quiet_hours/domain/quiet_hours_policy.dart';
import 'package:kozuchi/features/quiet_hours/domain/quiet_hours_settings.dart';

/// 通知スケジュールを静穏時間設定に照らして調整する抽象。
///
/// `adjust` は「実際に配信してよい時刻」を返す。
/// null を返した場合は通知を出さない（スケジュールしない）。
abstract interface class QuietHoursGuard {
  /// [scheduled] を静穏時間設定で調整する。null は「配信しない」。
  Future<DateTime?> adjust(DateTime scheduled);
}

/// 静穏時間の純粋ロジック。`DateTime.now()` は内部で呼ばない。
class QuietHoursService {
  const QuietHoursService._();

  /// [now] が [startMinutes]-[endMinutes] の静穏時間内か。
  ///
  /// - 分単位・ローカル時刻で判定する
  /// - 日跨ぎ（start > end）に対応する
  /// - start == end は「静穏時間なし」として常に false
  /// - 開始時刻は含み、終了時刻は含まない（半開区間）
  static bool isWithinQuietHours(
    DateTime now,
    int startMinutes,
    int endMinutes,
  ) {
    if (startMinutes == endMinutes) return false;
    final current = now.hour * 60 + now.minute;
    if (startMinutes < endMinutes) {
      return current >= startMinutes && current < endMinutes;
    }
    // 日跨ぎ（例 22:00 → 07:00）
    return current >= startMinutes || current < endMinutes;
  }

  /// 静穏時間内なら明ける時刻（[endMinutes]）を返す。
  ///
  /// 静穏時間外なら [now] をそのまま返す。秒以下は 0 に丸める。
  static DateTime deferUntil(
    DateTime now,
    int startMinutes,
    int endMinutes,
  ) {
    if (!isWithinQuietHours(now, startMinutes, endMinutes)) return now;

    final endHour = endMinutes ~/ 60;
    final endMinute = endMinutes % 60;
    var until = DateTime(now.year, now.month, now.day, endHour, endMinute);
    if (!until.isAfter(now)) {
      until = until.add(const Duration(days: 1));
    }
    return until;
  }

  /// 配信時刻を解決する。
  ///
  /// - 設定が無効: [scheduled] をそのまま
  /// - 静穏時間外: [scheduled] をそのまま
  /// - 静穏時間内 + [QuietHoursPolicy.defer]: 明ける時刻へ繰り延べ
  /// - 静穏時間内 + [QuietHoursPolicy.skip]: null（配信しない）
  static DateTime? resolveDelivery(
    QuietHoursSettings settings,
    DateTime scheduled,
  ) {
    if (!settings.enabled) return scheduled;
    if (!isWithinQuietHours(
      scheduled,
      settings.startMinutes,
      settings.endMinutes,
    )) {
      return scheduled;
    }
    switch (settings.policy) {
      case QuietHoursPolicy.defer:
        return deferUntil(
          scheduled,
          settings.startMinutes,
          settings.endMinutes,
        );
      case QuietHoursPolicy.skip:
        return null;
    }
  }

  /// 0時からの分を 'HH:mm' にする。
  static String formatMinutes(int minutes) {
    final hour = (minutes ~/ 60).toString().padLeft(2, '0');
    final minute = (minutes % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
