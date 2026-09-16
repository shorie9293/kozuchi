import 'package:flutter/material.dart';

import 'package:kozuchi/features/quick_template/domain/models/expense_template.dart';
import 'package:kozuchi/features/quick_template/domain/quick_template_service.dart';
import 'package:kozuchi/features/quick_template/presentation/quick_template_app_keys.dart';
import 'package:kozuchi/features/quick_template/presentation/screens/quick_template_management_screen.dart';

/// よく使う支出のチップ列（横スクロール）
///
/// テンプレート名（用途）と金額を併記したチップを横に並べ、
/// タップで [onSelected] に入力欄用の軽量値を渡す。
/// 「＋」で管理画面を開く。空のときは簡潔な空状態を表示する。
class QuickTemplateBar extends StatelessWidget {
  /// 表示するテンプレート一覧（使用回数順に並べ替えて表示する）
  final List<ExpenseTemplate> templates;

  /// テンプレートタップ時に呼ばれるコールバック
  final ValueChanged<ExpenseTemplateDraft> onSelected;

  /// 「＋」タップ時のコールバック（未指定時は管理画面を開く）
  final VoidCallback? onManage;

  const QuickTemplateBar({
    super.key,
    required this.templates,
    required this.onSelected,
    this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = QuickTemplateService.sortByUsage(templates);

    return SizedBox(
      key: QuickTemplateAppKeys.bar,
      height: 48,
      child: sorted.isEmpty
          ? _EmptyState(onManage: onManage)
          : ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final template in sorted)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      key: QuickTemplateAppKeys.chip(template.id),
                      label: Text(
                        '${template.purpose} ¥${template.amount}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      onPressed: () =>
                          onSelected(QuickTemplateService.draftOf(template)),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    key: QuickTemplateAppKeys.manageButton,
                    label: const Text('＋'),
                    onPressed: onManage ?? () => _openManagement(context),
                  ),
                ),
              ],
            ),
    );
  }

  /// 管理画面を開く。
  Future<void> _openManagement(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => const QuickTemplateManagementScreen(),
      ),
    );
  }
}

/// テンプレート未登録時の空状態。
class _EmptyState extends StatelessWidget {
  final VoidCallback? onManage;

  const _EmptyState({this.onManage});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'よく使う支出のテンプレートはまだありません',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ),
        ActionChip(
          key: QuickTemplateAppKeys.manageButton,
          label: const Text('＋'),
          onPressed: onManage,
        ),
      ],
    );
  }
}
