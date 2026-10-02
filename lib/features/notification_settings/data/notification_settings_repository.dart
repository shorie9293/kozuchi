import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:kozuchi/features/notification_settings/domain/notification_settings.dart';

/// 通知設定の永続化抽象。
abstract interface class NotificationSettingsRepository {
  /// 通知設定を読み出す（未保存・破損時は既定設定）。
  Future<NotificationSettings> load();

  /// 通知設定を保存する。
  Future<void> save(NotificationSettings settings);
}

/// SharedPreferences 実装。key は 'notification_settings_v1'。
class SharedPreferencesNotificationSettingsRepository
    implements NotificationSettingsRepository {
  /// 永続化キー。
  static const String storageKey = 'notification_settings_v1';

  const SharedPreferencesNotificationSettingsRepository();

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  @override
  Future<NotificationSettings> load() async {
    final prefs = await _prefs();
    final jsonString = prefs.getString(storageKey);
    if (jsonString == null) return NotificationSettings.defaults();

    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is Map<String, dynamic>) {
        return NotificationSettings.fromJson(decoded);
      }
      if (decoded is Map) {
        return NotificationSettings.fromJson(
          decoded.map<String, dynamic>(
            (key, value) => MapEntry(key.toString(), value),
          ),
        );
      }
      return NotificationSettings.defaults();
    } catch (_) {
      return NotificationSettings.defaults();
    }
  }

  @override
  Future<void> save(NotificationSettings settings) async {
    final prefs = await _prefs();
    await prefs.setString(storageKey, jsonEncode(settings.toJson()));
  }
}

/// メモリ内実装（試練用）。保存値を保持。
class InMemoryNotificationSettingsRepository
    implements NotificationSettingsRepository {
  /// 保存内容（試練の検証に使える）。
  NotificationSettings? stored;

  @override
  Future<NotificationSettings> load() async {
    return stored ?? NotificationSettings.defaults();
  }

  @override
  Future<void> save(NotificationSettings settings) async {
    stored = settings;
  }
}

/// 常に既定値を返し保存を無視する実装。
class NoopNotificationSettingsRepository
    implements NotificationSettingsRepository {
  const NoopNotificationSettingsRepository();

  @override
  Future<NotificationSettings> load() async => NotificationSettings.defaults();

  @override
  Future<void> save(NotificationSettings settings) async {}
}
