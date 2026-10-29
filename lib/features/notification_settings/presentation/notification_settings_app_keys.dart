import 'package:flutter/widgets.dart';

import 'package:kozuchi/features/notification_settings/domain/notification_settings.dart';

/// 通知設定画面の試練用 AppKeys。
class NotificationSettingsAppKeys {
  const NotificationSettingsAppKeys._();

  static const Key screen = Key('notificationSettingsScreen');
  static const Key masterSwitch = Key('notificationSettingsMasterSwitch');
  static const Key hourDropdown = Key('notificationSettingsHourDropdown');
  static const Key minuteDropdown = Key('notificationSettingsMinuteDropdown');
  static const Key timeLabel = Key('notificationSettingsTimeLabel');
  static const Key quietHoursEntry = Key('notificationSettingsQuietHoursEntry');

  /// 通知権限が拒否された時の恒久バナー。
  static const Key permissionBanner = Key('notificationSettingsPermissionBanner');

  /// 恒久バナーから OS のアプリ設定を開くボタン。
  static const Key permissionSettingsButton =
      Key('notificationSettingsPermissionSettingsButton');

  static Key kindSwitch(NotificationKind kind) =>
      Key('notificationSettings_kind_${kind.storageKey}');
}
