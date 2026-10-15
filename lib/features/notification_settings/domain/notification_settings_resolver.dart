import 'notification_settings.dart';

/// 旧キー（notification_enabled / notification_hour / notification_minute）から
/// 読んだ生の値。全キー未保存なら [empty] を使う。
class LegacyNotificationSettings {
  /// 旧キー notification_enabled の値（未保存なら null）。
  final bool? enabled;

  /// 旧キー notification_hour の値（未保存なら null）。
  final int? hour;

  /// 旧キー notification_minute の値（未保存なら null）。
  final int? minute;

  const LegacyNotificationSettings({this.enabled, this.hour, this.minute});

  /// 全旧キーが未保存のときの値。
  static const LegacyNotificationSettings empty = LegacyNotificationSettings();

  /// いずれかの旧キーが存在するか。
  bool get isPresent => enabled != null || hour != null || minute != null;

  /// 旧値から新設定を組み立てる。欠落・範囲外は既定値
  /// （enabled=true / 21:00 / 全種有効）へフォールバックする。
  NotificationSettings toSettings() {
    var h = 21;
    final rawHour = hour;
    if (rawHour != null && rawHour >= 0 && rawHour <= 23) {
      h = rawHour;
    }

    var m = 0;
    final rawMinute = minute;
    if (rawMinute != null && rawMinute >= 0 && rawMinute <= 59) {
      m = rawMinute;
    }

    return NotificationSettings(
      enabled: enabled ?? true,
      hour: h,
      minute: m,
      enabledKinds: NotificationKind.values.toSet(),
    );
  }
}

/// 保存済み新設定（notification_settings_v1）と旧キーから実効設定を決める
/// 純粋リゾルバ。Flutter 非依存。
class NotificationSettingsResolver {
  /// 移行が必要か（新キーが未保存 かつ 旧キーが存在する）。
  static bool needsMigration({
    required bool hasStoredSettings,
    required LegacyNotificationSettings legacy,
  }) =>
      !hasStoredSettings && legacy.isPresent;

  /// 実効設定を返す。
  ///
  /// - 移行が必要（新キー未保存・旧キーあり）: legacy.toSettings()
  /// - それ以外: stored をそのまま返す
  static NotificationSettings resolve({
    required NotificationSettings stored,
    required bool hasStoredSettings,
    required LegacyNotificationSettings legacy,
  }) {
    if (needsMigration(
      hasStoredSettings: hasStoredSettings,
      legacy: legacy,
    )) {
      return legacy.toSettings();
    }
    return stored;
  }

  /// 実効的に有効か（全体ON かつ その種類がON）。
  static bool isActive(NotificationSettings settings, NotificationKind kind) =>
      settings.enabled && settings.isKindEnabled(kind);
}
