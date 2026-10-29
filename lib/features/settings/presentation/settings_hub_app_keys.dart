import 'package:flutter/widgets.dart';

/// 設定ハブ画面の試練用 Key を一元管理する。
class SettingsHubAppKeys {
  SettingsHubAppKeys._();

  static const Key list = Key('settings_hub_list');
  static const Key textScaleTile = Key('settings_hub_tile_text_scale');
  static const Key reduceMotionTile = Key('settings_hub_tile_reduce_motion');
  static const Key appLockTile = Key('settings_hub_tile_app_lock');
  static const Key notificationTile = Key('settings_hub_tile_notification');
  static const Key quietHoursTile = Key('settings_hub_tile_quiet_hours');
  static const Key backupTile = Key('settings_hub_tile_backup');
  static const Key autoBackupTile = Key('settings_hub_tile_auto_backup');
  static const Key aboutTile = Key('settings_hub_tile_about');
  static const Key themeTile = Key('settings_hub_tile_theme');
}
