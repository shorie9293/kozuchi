import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ロック方式。
enum AppLockMethod { none, passcode, biometric }

/// アプリロック設定の永続化（SharedPreferences）。
class AppLockRepository {
  static const _kEnabled = 'app_lock.enabled';
  static const _kHash = 'app_lock.passcode_hash';
  static const _kMethod = 'app_lock.method';

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
    final bytes = utf8.encode('kozuchi-app-lock:$passcode');
    await _prefs.setString(_kHash, sha256.convert(bytes).toString());
  }

  bool verifyPasscode(String passcode) {
    final stored = getPasscodeHash();
    if (stored == null) return false;
    final bytes = utf8.encode('kozuchi-app-lock:$passcode');
    return _constantTimeEquals(stored, sha256.convert(bytes).toString());
  }

  Future<void> clearPasscode() => _prefs.remove(_kHash);
}

bool _constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}
