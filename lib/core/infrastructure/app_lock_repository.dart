import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ロック方式。
enum AppLockMethod { none, passcode, biometric }

/// アプリロック設定の永続化（SharedPreferences）。
///
/// パスコードは端末ごとにランダムな salt を付けた反復 SHA-256 で保存する
/// （`v2:<iterations>:<saltHex>:<hashHex>`）。旧形式（salt なし単発 SHA-256）
/// が保存されている場合は照合のみ旧方式で行い、成功時に v2 へ無強制移行する。
class AppLockRepository {
  static const _kEnabled = 'app_lock.enabled';
  static const _kHash = 'app_lock.passcode_hash';
  static const _kMethod = 'app_lock.method';
  static const _kRelockGrace = 'app_lock.relock_grace_seconds';
  static const _kFailedAttempts = 'app_lock.failed_attempts';
  static const _kLockedUntil = 'app_lock.locked_until_ms';

  static const String _v2Prefix = 'v2:';
  static const int _v2Iterations = 1200;
  static const int _saltBytes = 16;

  final SharedPreferences _prefs;
  AppLockRepository(this._prefs);

  bool isEnabled() => _prefs.getBool(_kEnabled) ?? false;

  Future<void> setEnabled(bool enabled) => _prefs.setBool(_kEnabled, enabled);

  AppLockMethod getMethod() {
    final name = _prefs.getString(_kMethod);
    return AppLockMethod.values
        .firstWhere((m) => m.name == name, orElse: () => AppLockMethod.none);
  }

  Future<void> setMethod(AppLockMethod method) =>
      _prefs.setString(_kMethod, method.name);

  String? getPasscodeHash() => _prefs.getString(_kHash);

  Future<void> setPasscode(String passcode) async {
    final salt = _randomSaltHex();
    final hash = _hashV2(passcode, salt, _v2Iterations);
    await _prefs.setString(
      _kHash,
      '$_v2Prefix$_v2Iterations:$salt:$hash',
    );
  }

  bool verifyPasscode(String passcode) {
    final stored = getPasscodeHash();
    if (stored == null) return false;
    if (stored.startsWith(_v2Prefix)) {
      final parsed = _parseV2(stored);
      if (parsed == null) return false;
      final computed = _hashV2(passcode, parsed.saltHex, parsed.iterations);
      return _constantTimeEquals(parsed.hashHex, computed);
    }
    // 旧形式（salt なし）。一致したら投げっぱなしで v2 へ移行する。
    final matches = _constantTimeEquals(stored, _legacyHashOf(passcode));
    if (matches) {
      unawaited(setPasscode(passcode));
    }
    return matches;
  }

  /// 旧形式（salt なし単発 SHA-256）のハッシュ。移行照合のためだけに残す。
  static String _legacyHashOf(String passcode) {
    final bytes = utf8.encode('kozuchi-app-lock:$passcode');
    return sha256.convert(bytes).toString();
  }

  static String _hashV2(String passcode, String saltHex, int iterations) {
    List<int> digest =
        sha256.convert(utf8.encode('$saltHex:$passcode')).bytes;
    for (var i = 1; i < iterations; i++) {
      digest = sha256.convert(digest).bytes;
    }
    return digest.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static String _randomSaltHex() {
    final random = Random.secure();
    final bytes = List<int>.generate(_saltBytes, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static _V2Hash? _parseV2(String stored) {
    final parts = stored.split(':');
    if (parts.length != 4) return null;
    final iterations = int.tryParse(parts[1]);
    if (iterations == null || iterations < 1) return null;
    if (parts[2].isEmpty || parts[3].isEmpty) return null;
    return _V2Hash(iterations, parts[2], parts[3]);
  }

  Future<void> clearPasscode() => _prefs.remove(_kHash);

  // --- 復帰時再施錠の猶予 ---

  /// 復帰時に再施錠するまでの猶予秒数（既定 0 = 即時）。
  int getRelockGraceSeconds() => _prefs.getInt(_kRelockGrace) ?? 0;

  Future<void> setRelockGraceSeconds(int seconds) async {
    if (seconds < 0) {
      throw ArgumentError.value(seconds, 'seconds', '0以上を指定せよ');
    }
    await _prefs.setInt(_kRelockGrace, seconds);
  }

  // --- 試行制限・ロックアウト ---

  int getFailedAttempts() => _prefs.getInt(_kFailedAttempts) ?? 0;

  Future<void> setFailedAttempts(int attempts) async {
    if (attempts < 0) {
      throw ArgumentError.value(attempts, 'attempts', '0以上を指定せよ');
    }
    await _prefs.setInt(_kFailedAttempts, attempts);
  }

  DateTime? getLockedUntil() {
    final ms = _prefs.getInt(_kLockedUntil);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setLockedUntil(DateTime? until) async {
    if (until == null) {
      await _prefs.remove(_kLockedUntil);
      return;
    }
    await _prefs.setInt(_kLockedUntil, until.millisecondsSinceEpoch);
  }

  Future<void> resetAttempts() async {
    await _prefs.remove(_kFailedAttempts);
    await _prefs.remove(_kLockedUntil);
  }
}

class _V2Hash {
  final int iterations;
  final String saltHex;
  final String hashHex;
  const _V2Hash(this.iterations, this.saltHex, this.hashHex);
}

bool _constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}
