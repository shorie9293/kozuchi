/// パスコード試行制限・ロックアウトの純粋ロジック。
///
/// 失敗回数からロックアウト時間を算出し、残り秒数・表示文言を提供する。
/// 時刻は引数注入（TZ 非依存）。
class LockAttemptPolicy {
  LockAttemptPolicy._();

  /// 無償で試せる失敗回数。これ未満ではロックアウトしない。
  static const int maxFreeAttempts = 5;

  /// 最初のロックアウト時間（30秒）。
  static const Duration baseLockout = Duration(seconds: 30);

  /// ロックアウトの上限（15分）。
  static const Duration maxLockout = Duration(minutes: 15);

  /// 現在ロックアウト中か。
  static bool isLockedOut(DateTime? lockedUntil, DateTime now) {
    if (lockedUntil == null) return false;
    return lockedUntil.isAfter(now);
  }

  /// 失敗回数に応じたロックアウト時間。
  ///
  /// 5回未満は zero。5回以降は 30秒 * 2^((n-5)~/5) で倍々に伸ばし、
  /// 上限 15分で頭打ちにする。
  static Duration lockoutFor(int failedAttempts) {
    if (failedAttempts < maxFreeAttempts) return Duration.zero;
    final steps = (failedAttempts - maxFreeAttempts) ~/ 5;
    if (steps >= 16) return maxLockout;
    final seconds = baseLockout.inSeconds * (1 << steps);
    if (seconds >= maxLockout.inSeconds) return maxLockout;
    return Duration(seconds: seconds);
  }

  /// ロックアウト残り秒数。過去・未設定は 0、端数は切り上げ。
  static int remainingSeconds(DateTime? lockedUntil, DateTime now) {
    if (lockedUntil == null) return 0;
    final ms = lockedUntil.difference(now).inMilliseconds;
    if (ms <= 0) return 0;
    return (ms / 1000).ceil();
  }

  /// ロックアウト中の案内文言。
  static String lockoutLabel(int seconds) =>
      // 秒は Dart の識別子文字のため、波括弧を外すと変数名として解釈される。
      // ignore: unnecessary_brace_in_string_interps
      'しばらく待ってから再試行してください（残り${seconds}秒）';
}
