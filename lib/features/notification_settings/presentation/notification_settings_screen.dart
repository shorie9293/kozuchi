import 'package:flutter/material.dart';

import 'package:takamagahara_ui/takamagahara_ui.dart';
import 'package:kozuchi/features/notification_settings/data/notification_settings_repository.dart';
import 'package:kozuchi/features/notification_settings/domain/notification_settings.dart';
import 'package:kozuchi/core/infrastructure/notification_permission_requester.dart';
import 'package:kozuchi/features/notification_settings/presentation/notification_settings_app_keys.dart';

/// 通知設定画面。
///
/// 設定の読み書きは [NotificationSettingsRepository] に委ねる。
/// 未指定の場合は SharedPreferences 実装を用いる。
class NotificationSettingsScreen extends StatefulWidget {
  /// 永続化の委譲先（試練では InMemory 実装を注入する）。
  final NotificationSettingsRepository? repository;

  /// 保存完了後に呼ばれるフック。
  ///
  /// 通知の再スケジュール等の副作用を行うために用いる
  /// （例: `NotificationService.scheduleDailyReminder()` を await する）。
  /// 保存が成功した後、[NotificationSettings] の最新値を渡して呼ばれる。
  /// 例外は画面側で握り潰されるため、呼び出し側で致命傷にはならない。
  final Future<void> Function(NotificationSettings settings)? onSaved;

  /// 静穏時間（おやすみモード）画面への導線を生成するビルダー。
  ///
  /// null の場合は AppBar に導線を出さない（後方互換）。
  final WidgetBuilder? quietHoursScreenBuilder;

  /// 通知権限の要求窓口。
  ///
  /// null（未注入）の場合は権限要求も拒否バナーも行わない＝従来挙動
  /// （既存の試練・既存の呼び出しを無破壊に保つ）。
  final NotificationPermissionRequester? permissionRequester;

  const NotificationSettingsScreen({
    super.key,
    this.repository,
    this.onSaved,
    this.quietHoursScreenBuilder,
    this.permissionRequester,
  });

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  NotificationSettings? _settings;
  NotificationSettingsRepository? _repository;
  NotificationPermissionStatus? _permission;
  bool _askedOnce = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository;
    _load();
    _ensurePermission(alreadyAsked: _askedOnce);
  }

  /// 通知権限を確保する。
  ///
  /// 画面表示時に 1 回だけ、および通知を ON に切り替えた時に呼ばれる。
  Future<void> _ensurePermission({bool alreadyAsked = false}) async {
    final requester = widget.permissionRequester;
    if (requester == null) return;
    final status = await requester.ensure(alreadyAsked: alreadyAsked);
    _askedOnce = true;
    if (!mounted) return;
    setState(() => _permission = status);
  }

  bool get _showPermissionBanner =>
      _permission == NotificationPermissionStatus.denied ||
      _permission == NotificationPermissionStatus.permanentlyDenied;

  Widget _buildPermissionBanner(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: NotificationSettingsAppKeys.permissionBanner,
      color: scheme.errorContainer,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.notifications_off, color: scheme.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '通知が許可されていません。'
                  '端末の設定 > アプリ > 通知 から許可してください。',
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: NotificationSettingsAppKeys.permissionSettingsButton,
              onPressed: () => widget.permissionRequester?.openAppSettings(),
              child: const Text('設定を開く'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _load() async {
    final repo =
        _repository ?? SharedPreferencesNotificationSettingsRepository();
    _repository = repo;
    final settings = await repo.load();
    if (!mounted) return;
    setState(() => _settings = settings);
  }

  Future<void> _update(NotificationSettings next) async {
    await _repository!.save(next);
    // 保存成功後、通知の再スケジュール等の副作用フックを呼ぶ。
    // 失敗しても画面は壊さない（debugPrint のみ）。
    try {
      await widget.onSaved?.call(next);
    } catch (e) {
      debugPrint('NotificationSettingsScreen: onSaved failed: $e');
    }
    if (!mounted) return;
    setState(() => _settings = next);
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    if (settings == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final masterOn = settings.enabled;

    return Scaffold(
      key: NotificationSettingsAppKeys.screen,
      appBar: AppBar(
        title: const Text('通知設定'),
        actions: [
          if (widget.quietHoursScreenBuilder != null)
            IconButton(
              key: NotificationSettingsAppKeys.quietHoursEntry,
              icon: const Icon(Icons.nightlight_round),
              tooltip: 'おやすみモード（静穏時間）',
              onPressed: () {
                final builder = widget.quietHoursScreenBuilder;
                if (builder == null) return;
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: builder),
                );
              },
            ),
        ],
      ),
      body: ListView(
        children: [
          if (_showPermissionBanner) _buildPermissionBanner(context),
          SemanticHelper.toggle(
            testId: 'notif_tgl_master',
            value: settings.enabled,
            child: SwitchListTile(
              key: NotificationSettingsAppKeys.masterSwitch,
              title: const Text('通知を受け取る'),
              value: settings.enabled,
              onChanged: (value) {
                _update(settings.copyWith(enabled: value));
                // 通知を ON に切り替えた時だけ権限を要求する。
                if (value) _ensurePermission();
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'リマインド時刻',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ListTile(
            title: Text(
              settings.timeLabel,
              key: NotificationSettingsAppKeys.timeLabel,
            ),
            trailing: SemanticHelper.interactive(
              testId: 'notif_btn_hour',
              label: 'リマインド時刻（時）を選択',
              child: DropdownButton<int>(
                key: NotificationSettingsAppKeys.hourDropdown,
                value: settings.hour,
                onChanged: masterOn
                    ? (hour) {
                        if (hour == null) return;
                        _update(settings.copyWith(hour: hour));
                      }
                    : null,
                items: <int>[
                  for (var h = 0; h <= 23; h++) h,
                ]
                    .map(
                      (h) => DropdownMenuItem<int>(
                        value: h,
                        child: Text('$h時'),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          ListTile(
            title: SemanticHelper.interactive(
              testId: 'notif_btn_minute',
              label: 'リマインド時刻（分）を選択',
              child: DropdownButton<int>(
                key: NotificationSettingsAppKeys.minuteDropdown,
                value: settings.minute,
                onChanged: masterOn
                    ? (minute) {
                        if (minute == null) return;
                        _update(settings.copyWith(minute: minute));
                      }
                    : null,
                items: <int>[
                  for (var m = 0; m <= 55; m += 5) m,
                ]
                    .map(
                      (m) => DropdownMenuItem<int>(
                        value: m,
                        child: Text('$m分'),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          const Divider(height: 1),
          for (final kind in NotificationKind.values)
            SemanticHelper.toggle(
              testId: 'notif_tgl_kind_${kind.storageKey}',
              value: settings.isKindEnabled(kind),
              child: SwitchListTile(
                key: NotificationSettingsAppKeys.kindSwitch(kind),
                title: Text(kind.label),
                subtitle: Text(kind.description),
                value: settings.isKindEnabled(kind),
                onChanged:
                    masterOn ? (_) => _update(settings.toggleKind(kind)) : null,
              ),
            ),
        ],
      ),
    );
  }
}
