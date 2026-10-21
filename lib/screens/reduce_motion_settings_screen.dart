import 'package:flutter/material.dart';

import 'package:kozuchi/core/theme/reduce_motion_repository.dart';
import 'package:kozuchi/core/theme/reduce_motion_setting.dart';

/// 動きを減らす（Reduce Motion）設定画面 — 3択の選択と永続化
///
/// WCAG 2.3.3（インタラクションによるアニメーション）に配慮し、
/// 端末のアクセシビリティ設定に対するアプリ内の上書き方針を選べる。
class ReduceMotionSettingsScreen extends StatefulWidget {
  /// 永続化先。null なら [ReduceMotionRepository] を用いる。
  final ReduceMotionRepository? repository;

  /// 現在の設定（ルートが保持する値）。null なら [ReduceMotionSetting.system]。
  final ReduceMotionSetting? initial;

  /// 保存後にルートへ反映するためのコールバック。
  final ValueChanged<ReduceMotionSetting>? onChanged;

  const ReduceMotionSettingsScreen({
    super.key,
    this.repository,
    this.initial,
    this.onChanged,
  });

  @override
  State<ReduceMotionSettingsScreen> createState() =>
      _ReduceMotionSettingsScreenState();
}

class _ReduceMotionSettingsScreenState extends State<ReduceMotionSettingsScreen> {
  late ReduceMotionSetting _setting;

  ReduceMotionRepository get _repository =>
      widget.repository ?? const ReduceMotionRepository();

  @override
  void initState() {
    super.initState();
    _setting = widget.initial ?? ReduceMotionSetting.system;
  }

  Future<void> _select(ReduceMotionSetting setting) async {
    setState(() => _setting = setting);
    await _repository.save(setting);
    widget.onChanged?.call(setting);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('動きを減らす設定')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('アプリ内のアニメーション（画面遷移・演出）の動きを調整できます。'),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.accessibility_new,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'アクセシビリティ配慮',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'WCAG 2.3.3（インタラクションによるアニメーション）に配慮し、'
                    '動きが苦手な方でも快適に使えるよう演出を抑えられます。'
                    '「システムに従う」を選ぶと端末の「アニメーションを削除」設定に追従します。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          for (final option in ReduceMotionSetting.values)
            RadioListTile<ReduceMotionSetting>(
              key: ValueKey('reduce_motion_option_${option.storageKey}'),
              value: option,
              groupValue: _setting,
              onChanged: (value) {
                if (value == null) return;
                _select(value);
              },
              secondary: Icon(option.icon),
              title: Text(option.label),
              subtitle: switch (option) {
                ReduceMotionSetting.system => const Text('端末の設定に合わせます'),
                ReduceMotionSetting.off => const Text('端末設定より優先して動きを表示します'),
                ReduceMotionSetting.on => const Text('演出を抑えて表示します'),
              },
            ),
        ],
      ),
    );
  }
}
