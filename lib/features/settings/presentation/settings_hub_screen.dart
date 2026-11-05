import 'package:flutter/material.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';

import 'package:kozuchi/core/crash/crash_log_repository.dart';
import 'package:kozuchi/core/crash/crash_log_screen.dart';
import 'package:kozuchi/core/infrastructure/app_lock_settings_screen.dart';
import 'package:kozuchi/core/infrastructure/notification_permission_requester.dart';
import 'package:kozuchi/core/infrastructure/notification_service.dart';
import 'package:kozuchi/core/logging/app_logger.dart';
import 'package:kozuchi/features/about/presentation/about_screen.dart';
import 'package:kozuchi/features/auto_backup/data/auto_backup_restorer_impl.dart';
import 'package:kozuchi/features/auto_backup/data/auto_backup_sharer_impl.dart';
import 'package:kozuchi/features/auto_backup/data/auto_backup_status_store.dart';
import 'package:kozuchi/features/auto_backup/data/auto_backup_store.dart';
import 'package:kozuchi/features/auto_backup/domain/auto_backup_service.dart';
import 'package:kozuchi/features/auto_backup/domain/auto_backup_status.dart';
import 'package:kozuchi/features/auto_backup/presentation/auto_backup_screen.dart';
import 'package:kozuchi/features/backup/data/backup_repository.dart';
import 'package:kozuchi/features/backup/domain/backup_service.dart';
import 'package:kozuchi/features/backup/presentation/backup_screen.dart';
import 'package:kozuchi/features/help/presentation/help_screen.dart';
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
  final WidgetBuilder? autoBackupBuilder;
  final WidgetBuilder? aboutBuilder;
  final WidgetBuilder? crashLogBuilder;
  final WidgetBuilder? helpBuilder;

  /// クラッシュ記録の読み出し元（未指定なら端末内ファイル実装）。
  final CrashLogRepository? crashLogRepository;

  /// 自動バックアップの状態の読み出し元（未指定なら警告バッジを出さない）。
  final AutoBackupStatusStore? autoBackupStatusStore;

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
    this.autoBackupBuilder,
    this.aboutBuilder,
    this.crashLogBuilder,
    this.helpBuilder,
    this.crashLogRepository,
    this.autoBackupStatusStore,
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
      permissionRequester: PlatformNotificationPermissionRequester(),
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
          appLog.warn('scheduleDailyReminder failed', e);
        }
      },
    );
  }

  /// 自動バックアップ一覧画面の既定結線。
  ///
  /// 保管庫は起動時バックアップと同一の [FileAutoBackupStore]、
  /// 復元の適用先は既存の手動バックアップ経路（SharedPreferences）を使う。
  static Widget buildAutoBackupScreen() {
    final store = FileAutoBackupStore();
    final repository = SharedPreferencesBackupRepository();
    final service = BackupService();
    Future<String> buildJson() async =>
        service.exportJson(await repository.collect());
    return AutoBackupScreen(
      store: store,
      restorer: AutoBackupRestorerImpl(
        store: store,
        buildCurrentJson: buildJson,
        applyBackup: (json) async {
          await repository.restore(service.parse(json));
        },
      ),
      sharer: SharePlusAutoBackupSharer(),
      statusStore: FileAutoBackupStatusStore(),
      onBackupNow: () async {
        await AutoBackupService(
          store: store,
          statusStore: FileAutoBackupStatusStore(),
        ).run(buildJson);
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
          _CrashLogTile(
            repository: crashLogRepository ?? FileCrashLogRepository(),
            builder: crashLogBuilder ??
                (_) => CrashLogScreen(
                      repository:
                          crashLogRepository ?? FileCrashLogRepository(),
                    ),
          ),
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
              reduceMotionBuilder ?? (_) => const ReduceMotionSettingsScreen(),
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
          if (autoBackupStatusStore == null)
            _tile(
              key: SettingsHubAppKeys.autoBackupTile,
              testId: SemanticHelper.createTestId(
                SemanticTypes.button,
                'settings_hub_auto_backup',
              ),
              label: '自動バックアップ',
              icon: Icons.history,
              onTap: () => _push(
                context,
                autoBackupBuilder ?? (_) => buildAutoBackupScreen(),
              ),
            )
          else
            _AutoBackupStatusTile(
              store: autoBackupStatusStore!,
              builder: autoBackupBuilder ?? (_) => buildAutoBackupScreen(),
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
          _tile(
            key: SettingsHubAppKeys.helpTile,
            testId: SemanticHelper.createTestId(
              SemanticTypes.button,
              'settings_hub_help',
            ),
            label: '遊び方・ヘルプ',
            icon: Icons.help_outline,
            onTap: () => _push(
              context,
              helpBuilder ?? (_) => const HelpScreen(),
            ),
          ),
        ],
      ),
    );
  }
}

/// 「不具合の報告」タイル。記録が1件以上あるときだけ件数を併記する。
class _CrashLogTile extends StatefulWidget {
  const _CrashLogTile({required this.repository, required this.builder});

  final CrashLogRepository repository;
  final WidgetBuilder builder;

  @override
  State<_CrashLogTile> createState() => _CrashLogTileState();
}

class _CrashLogTileState extends State<_CrashLogTile> {
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await widget.repository.loadAll();
    if (!mounted) return;
    setState(() => _count = entries.length);
  }

  Future<void> _open() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: widget.builder),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final label = _count > 0 ? '不具合の報告 ($_count)' : '不具合の報告';
    return SemanticHelper.interactive(
      testId: SemanticHelper.createTestId(
        SemanticTypes.button,
        'settings_hub_crash_log',
      ),
      label: label,
      child: ListTile(
        key: SettingsHubAppKeys.crashLogTile,
        leading: const Icon(Icons.info_outline),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right),
        onTap: _open,
      ),
    );
  }
}

/// 「自動バックアップ」タイル。連続失敗が閾値以上なら警告文言を併記する。
class _AutoBackupStatusTile extends StatefulWidget {
  const _AutoBackupStatusTile({required this.store, required this.builder});

  final AutoBackupStatusStore store;
  final WidgetBuilder builder;

  @override
  State<_AutoBackupStatusTile> createState() => _AutoBackupStatusTileState();
}

class _AutoBackupStatusTileState extends State<_AutoBackupStatusTile> {
  AutoBackupStatus? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    AutoBackupStatus? status;
    try {
      status = await widget.store.load();
    } catch (_) {
      status = null;
    }
    if (!mounted) return;
    setState(() => _status = status);
  }

  Future<void> _open() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: widget.builder),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final degraded = _status?.isDegraded == true;
    final subtitle = degraded
        ? '自動バックアップに失敗しています'
            '（${_status?.consecutiveFailures ?? 0}回連続）'
        : '起動時の控えを一覧・復元・共有する';
    return SemanticHelper.interactive(
      testId: SemanticHelper.createTestId(
        SemanticTypes.button,
        'settings_hub_auto_backup',
      ),
      label: '自動バックアップ',
      child: ListTile(
        key: SettingsHubAppKeys.autoBackupTile,
        leading: Icon(
          degraded ? Icons.warning_amber_outlined : Icons.history,
        ),
        title: const Text('自動バックアップ'),
        subtitle: Text(
          subtitle,
          key: degraded ? SettingsHubAppKeys.autoBackupWarning : null,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: _open,
      ),
    );
  }
}
