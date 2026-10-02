import 'package:flutter/material.dart';

import 'package:kozuchi/features/notification_settings/data/notification_settings_repository.dart';
import 'package:kozuchi/features/notification_settings/domain/notification_settings.dart';
import 'package:kozuchi/features/notification_settings/presentation/notification_settings_app_keys.dart';

/// 通知設定画面。
///
/// 設定の読み書きは [NotificationSettingsRepository] に委ねる。
/// 未指定の場合は SharedPreferences 実装を用いる。
class NotificationSettingsScreen extends StatefulWidget {
  /// 永続化の委譲先（試練では InMemory 実装を注入する）。
  final NotificationSettingsRepository? repository;

  const NotificationSettingsScreen({super.key, this.repository});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  NotificationSettings? _settings;
  NotificationSettingsRepository? _repository;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository;
    _load();
  }

  Future<void> _load() async {
    final repo = _repository ?? SharedPreferencesNotificationSettingsRepository();
    _repository = repo;
    final settings = await repo.load();
    if (!mounted) return;
    setState(() => _settings = settings);
  }

  Future<void> _update(NotificationSettings next) async {
    await _repository!.save(next);
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
      appBar: AppBar(title: const Text('通知設定')),
      body: ListView(
        children: [
          SwitchListTile(
            key: NotificationSettingsAppKeys.masterSwitch,
            title: const Text('通知を受け取る'),
            value: settings.enabled,
            onChanged: (value) =>
                _update(settings.copyWith(enabled: value)),
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
            trailing: DropdownButton<int>(
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
          ListTile(
            title: DropdownButton<int>(
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
          const Divider(height: 1),
          for (final kind in NotificationKind.values)
            SwitchListTile(
              key: NotificationSettingsAppKeys.kindSwitch(kind),
              title: Text(kind.label),
              subtitle: Text(kind.description),
              value: settings.isKindEnabled(kind),
              onChanged: masterOn
                  ? (_) => _update(settings.toggleKind(kind))
                  : null,
            ),
        ],
      ),
    );
  }
}
