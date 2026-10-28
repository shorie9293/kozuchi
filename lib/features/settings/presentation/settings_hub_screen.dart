import 'package:flutter/material.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';

import 'package:kozuchi/core/infrastructure/app_lock_settings_screen.dart';
import 'package:kozuchi/core/infrastructure/notification_service.dart';
import 'package:kozuchi/features/about/presentation/about_screen.dart';
import 'package:kozuchi/features/backup/presentation/backup_screen.dart';
import 'package:kozuchi/features/notification_settings/presentation/notification_settings_screen.dart';
import 'package:kozuchi/features/quiet_hours/data/quiet_hours_repository.dart';
import 'package:kozuchi/features/quiet_hours/presentation/quiet_hours_settings_screen.dart';
import 'package:kozuchi/features/settings/presentation/settings_hub_app_keys.dart';
import 'package:kozuchi/screens/reduce_motion_settings_screen.dart';
import 'package:kozuchi/screens/text_scale_settings_screen.dart';

/// 散在する設定画面を1画面に集約するハブ。
///
/// 各項目の遷移先は [WidgetBuilder] で注入できる（未指定なら実画面）。
/// テーマ切替はこの現世では画面ではなくルートのコールバックで行うため、
/// [onToggleTheme] をそのまま受け取って委譲する。
class SettingsHubScreen extends StatelessWidget {
  final WidgetBuilder? textScaleBuilder;
  final WidgetBuilder? reduceMotionBuilder;
  final WidgetBuilder? appLockBuilder;
  final WidgetBuilder? notificationBuilder;
  final WidgetBuilder? quietHoursBuilder;
  final WidgetBuilder? backupBuilder;
  final WidgetBuilder? aboutBuilder;

  /// 文字サイズの現在値（ルートが保持する値）。
  final double currentTextScale;

  /// 文字サイズ変更のルート反映コールバック。
  final ValueChanged<double>? onTextScaleChanged;

  /// テーマ切替コールバック。null なら項目は無効表示。
  final VoidCallback? onToggleTheme;

  const SettingsHubScreen({
    super.key,
    this.textScaleBuilder,
    this.reduceMotionBuilder,
    this.appLockBuilder,
    this.notificationBuilder,
    this.quietHoursBuilder,
    this.backupBuilder,
    this.aboutBuilder,
    this.currentTextScale = 1.0,
    this.onTextScaleChanged,
    this.onToggleTheme,
  });

  /// 通知設定画面の既定結線。
  ///
  /// 保存後に [NotificationService.scheduleDailyReminder] を実行し、変更を
  /// 通知スケジュールへ即時反映する（main_screen の既存結線と同一）。
  static Widget buildNotificationSettings() {
    return NotificationSettingsScreen(
      quietHoursScreenBuilder: (_) => const QuietHoursSettingsScreen(),
      onSaved: (settings) async {
        try {
          await NotificationService().scheduleDailyReminder(
            guard: const QuietHoursRepositoryGuard(
              SharedPreferencesQuietHoursRepository(),
            ),
          );
        } catch (e) {
          // プラットフォームチャネルが無い環境（試練等）では例外になり得る。
          debugPrint('scheduleDailyReminder failed: $e');
        }
      },
    );
  }

  void _push(BuildContext context, WidgetBuilder builder) {
    Navigator.of(context).push(MaterialPageRoute(builder: builder));
  }

  Widget _tile({
    required Key key,
    required String testId,
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return SemanticHelper.interactive(
      testId: testId,
      label: label,
      child: ListTile(
        key: key,
        leading: Icon(icon),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right),
        enabled: onTap != null,
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        key: SettingsHubAppKeys.list,
        children: [
          _tile(
            key: SettingsHubAppKeys.textScaleTile,
            testId: SemanticHelper.createTestId(
              SemanticTypes.button,
              'settings_hub_text_scale',
            ),
            label: '文字サイズ',
            icon: Icons.format_size,
            onTap: () => _push(
              context,
              textScaleBuilder ??
                  (_) => TextScaleSettingsScreen(
                        currentScale: currentTextScale,
                        onScaleChanged: onTextScaleChanged ?? (_) {},
                      ),
            ),
          ),
          _tile(
            key: SettingsHubAppKeys.reduceMotionTile,
            testId: SemanticHelper.createTestId(
              SemanticTypes.button,
              'settings_hub_reduce_motion',
            ),
            label: '動きを減らす',
            icon: Icons.motion_photos_off,
            onTap: () => _push(
              context,
              reduceMotionBuilder ??
                  (_) => const ReduceMotionSettingsScreen(),
            ),
          ),
          _tile(
            key: SettingsHubAppKeys.appLockTile,
            testId: SemanticHelper.createTestId(
              SemanticTypes.button,
              'settings_hub_app_lock',
            ),
            label: 'アプリロック',
            icon: Icons.lock_outline,
            onTap: () => _push(
              context,
              appLockBuilder ?? (_) => const AppLockSettingsScreen(),
            ),
          ),
          _tile(
            key: SettingsHubAppKeys.notificationTile,
            testId: SemanticHelper.createTestId(
              SemanticTypes.button,
              'settings_hub_notification',
            ),
            label: '通知設定',
            icon: Icons.notifications_outlined,
            onTap: () => _push(
              context,
              notificationBuilder ?? (_) => buildNotificationSettings(),
            ),
          ),
          _tile(
            key: SettingsHubAppKeys.quietHoursTile,
            testId: SemanticHelper.createTestId(
              SemanticTypes.button,
              'settings_hub_quiet_hours',
            ),
            label: '静穏時間（おやすみモード）',
            icon: Icons.nightlight_outlined,
            onTap: () => _push(
              context,
              quietHoursBuilder ?? (_) => const QuietHoursSettingsScreen(),
            ),
          ),
          _tile(
            key: SettingsHubAppKeys.backupTile,
            testId: SemanticHelper.createTestId(
              SemanticTypes.button,
              'settings_hub_backup',
            ),
            label: 'バックアップ',
            icon: Icons.backup_outlined,
            onTap: () => _push(
              context,
              backupBuilder ?? (_) => const BackupScreen(),
            ),
          ),
          _tile(
            key: SettingsHubAppKeys.aboutTile,
            testId: SemanticHelper.createTestId(
              SemanticTypes.button,
              'settings_hub_about',
            ),
            label: 'アプリについて',
            icon: Icons.info_outline,
            onTap: () => _push(
              context,
              aboutBuilder ?? (_) => const AboutScreen(),
            ),
          ),
          SemanticHelper.interactive(
            testId: SemanticHelper.createTestId(
              SemanticTypes.button,
              'settings_hub_theme',
            ),
            label: 'テーマ切替',
            child: ListTile(
              key: SettingsHubAppKeys.themeTile,
              leading: const Icon(Icons.brightness_6_outlined),
              title: const Text('テーマ切替'),
              trailing: const Icon(Icons.swap_horiz),
              enabled: onToggleTheme != null,
              onTap: onToggleTheme,
            ),
          ),
        ],
      ),
    );
  }
}
