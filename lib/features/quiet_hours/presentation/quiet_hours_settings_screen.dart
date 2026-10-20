import 'package:flutter/material.dart';

import 'package:takamagahara_ui/takamagahara_ui.dart';
import 'package:kozuchi/features/quiet_hours/data/quiet_hours_repository.dart';
import 'package:kozuchi/features/quiet_hours/domain/quiet_hours_policy.dart';
import 'package:kozuchi/features/quiet_hours/domain/quiet_hours_service.dart';
import 'package:kozuchi/features/quiet_hours/domain/quiet_hours_settings.dart';
import 'package:kozuchi/features/quiet_hours/presentation/quiet_hours_app_keys.dart';

/// 静穏時間（おやすみモード）設定画面。
///
/// 編集は下書き（ローカル状態）に対して行い、保存時に
/// [QuietHoursRepository] へ永続化したうえで必ず再読込する。
class QuietHoursSettingsScreen extends StatefulWidget {
  /// 永続化の委譲先（未指定なら SharedPreferences 実装）。
  final QuietHoursRepository? repository;

  /// プレビュー用の現在時刻（未指定なら `DateTime.now()`）。
  /// 試練で固定するために注入できる。
  final DateTime? now;

  /// 保存完了後に最新設定を渡して呼ばれるフック。
  final ValueChanged<QuietHoursSettings>? onSaved;

  const QuietHoursSettingsScreen({
    super.key,
    this.repository,
    this.now,
    this.onSaved,
  });

  @override
  State<QuietHoursSettingsScreen> createState() =>
      _QuietHoursSettingsScreenState();
}

class _QuietHoursSettingsScreenState extends State<QuietHoursSettingsScreen> {
  QuietHoursSettings? _settings;
  QuietHoursRepository? _repository;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository;
    _load();
  }

  Future<void> _load() async {
    final repo = _repository ?? const SharedPreferencesQuietHoursRepository();
    _repository = repo;
    final settings = await repo.load();
    if (!mounted) return;
    setState(() => _settings = settings);
  }

  Future<void> _save() async {
    final current = _settings;
    if (current == null || _saving) return;
    setState(() => _saving = true);
    await _repository!.save(current);
    // 保存後は必ずリポジトリから再読込する（単一情報源の担保）。
    final reloaded = await _repository!.load();
    if (!mounted) return;
    setState(() {
      _settings = reloaded;
      _saving = false;
    });
    try {
      widget.onSaved?.call(reloaded);
    } catch (e) {
      debugPrint('QuietHoursSettingsScreen: onSaved failed: $e');
    }
  }

  void _update(QuietHoursSettings next) {
    setState(() => _settings = next);
  }

  List<int> _minuteItems(int current) {
    final items = <int>{for (var m = 0; m <= 55; m += 5) m, current}.toList()
      ..sort();
    return items;
  }

  String _previewText(QuietHoursSettings s) {
    if (!s.enabled) {
      return 'おやすみモードはオフです。通知は通常どおり届きます。';
    }
    final now = widget.now ?? DateTime.now();
    final inQuiet = QuietHoursService.isWithinQuietHours(
      now,
      s.startMinutes,
      s.endMinutes,
    );
    final base = '${s.startLabel}〜${s.endLabel} の間はおやすみモードです。';
    final effect = s.policy == QuietHoursPolicy.defer
        ? 'この間の通知は翌朝 ${s.endLabel} にまとめて届けます。'
        : 'この間の通知は通知しない（そのまま破棄）ます。';
    final nowNote = inQuiet ? 'いまはおやすみモード中です。' : 'いまは静穏時間外です。';
    return '$base$effect$nowNote';
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    if (settings == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      key: QuietHoursAppKeys.screen,
      appBar: AppBar(title: const Text('おやすみモード')),
      body: ListView(
        children: [
          SemanticHelper.toggle(
            testId: 'quiet_tgl_enabled',
            value: settings.enabled,
            child: SwitchListTile(
              key: QuietHoursAppKeys.enabledSwitch,
              title: const Text('おやすみモードを使う'),
              subtitle: const Text('指定した時間帯の通知を静かにします'),
              value: settings.enabled,
              onChanged: (value) => _update(settings.copyWith(enabled: value)),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '静かにする時間帯',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ListTile(
            title: const Text('開始'),
            subtitle: Text(
              settings.startLabel,
              key: QuietHoursAppKeys.startLabel,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SemanticHelper.interactive(
                  testId: 'quiet_btn_start_hour',
                  label: '開始時刻（時）を選択',
                  child: DropdownButton<int>(
                    key: QuietHoursAppKeys.startHourDropdown,
                    value: settings.startHour,
                    onChanged: (hour) {
                      if (hour == null) return;
                      _update(settings.copyWith(startHour: hour));
                    },
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
                SemanticHelper.interactive(
                  testId: 'quiet_btn_start_minute',
                  label: '開始時刻（分）を選択',
                  child: DropdownButton<int>(
                    key: QuietHoursAppKeys.startMinuteDropdown,
                    value: settings.startMinute,
                    onChanged: (minute) {
                      if (minute == null) return;
                      _update(settings.copyWith(startMinute: minute));
                    },
                    items: _minuteItems(settings.startMinute)
                        .map(
                          (m) => DropdownMenuItem<int>(
                            value: m,
                            child: Text('$m分'),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            title: const Text('終了'),
            subtitle: Text(
              settings.endLabel,
              key: QuietHoursAppKeys.endLabel,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SemanticHelper.interactive(
                  testId: 'quiet_btn_end_hour',
                  label: '終了時刻（時）を選択',
                  child: DropdownButton<int>(
                    key: QuietHoursAppKeys.endHourDropdown,
                    value: settings.endHour,
                    onChanged: (hour) {
                      if (hour == null) return;
                      _update(settings.copyWith(endHour: hour));
                    },
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
                SemanticHelper.interactive(
                  testId: 'quiet_btn_end_minute',
                  label: '終了時刻（分）を選択',
                  child: DropdownButton<int>(
                    key: QuietHoursAppKeys.endMinuteDropdown,
                    value: settings.endMinute,
                    onChanged: (minute) {
                      if (minute == null) return;
                      _update(settings.copyWith(endMinute: minute));
                    },
                    items: _minuteItems(settings.endMinute)
                        .map(
                          (m) => DropdownMenuItem<int>(
                            value: m,
                            child: Text('$m分'),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'この時間帯の通知',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          RadioGroup<QuietHoursPolicy>(
            groupValue: settings.policy,
            onChanged: (value) {
              if (value == null) return;
              _update(settings.copyWith(policy: value));
            },
            child: Column(
              children: [
                for (final policy in QuietHoursPolicy.values)
                  RadioListTile<QuietHoursPolicy>(
                    key: QuietHoursAppKeys.policyRadio(policy),
                    title: Text(policy.label),
                    value: policy,
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _previewText(settings),
              key: QuietHoursAppKeys.previewText,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: SemanticHelper.interactive(
              testId: 'quiet_btn_save',
              label: 'おやすみモード設定を保存',
              child: FilledButton(
                key: QuietHoursAppKeys.saveButton,
                onPressed: _saving ? null : _save,
                child: const Text('保存'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
