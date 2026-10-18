import 'package:flutter/material.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';

import 'package:kozuchi/features/budget/data/closing_day_repository.dart';
import 'package:kozuchi/features/budget/domain/budget_period.dart';
import 'package:kozuchi/features/budget/presentation/budget_period_app_keys.dart';

/// 家計の「締め日」設定セクション。
///
/// 現在の締め日・期間の説明・現在期間プレビューを表示し、
/// 「変更」から 1〜28 の締め日を選んで永続化できる。
///
/// - 未保存時は 1（暦月）＝従来挙動。
/// - 保存は [ClosingDayRepository.save] まで必ず到達し、
///   保存後に再読込（[ClosingDayRepository.load]）して表示を更新する。
/// - [now] は試練で固定日付を注入するための時刻供給関数。
class BudgetPeriodSection extends StatefulWidget {
  /// 締め日の永続化リポジトリ。
  final ClosingDayRepository repository;

  /// 現在時刻の取得関数（未注入時は実時計）。
  final DateTime Function() now;

  const BudgetPeriodSection({
    super.key,
    required this.repository,
    this.now = DateTime.now,
  });

  @override
  State<BudgetPeriodSection> createState() => _BudgetPeriodSectionState();
}

class _BudgetPeriodSectionState extends State<BudgetPeriodSection> {
  /// 表示中の締め日（未保存時は既定値 1）。
  int _closingDay = BudgetPeriodService.defaultClosingDay;

  @override
  void initState() {
    super.initState();
    _loadClosingDay();
  }

  Future<void> _loadClosingDay() async {
    final loaded = await widget.repository.load();
    if (!mounted) return;
    final normalized = BudgetPeriodService.normalize(loaded);
    if (normalized == _closingDay) return;
    setState(() => _closingDay = normalized);
  }

  /// 締め日変更ダイアログを開き、保存まで到達させる。
  Future<void> _openEditDialog() async {
    var selected = _closingDay;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('家計の締め日を変更'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '給与日などに合わせて、1ヶ月の区切りを選べます。',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                DropdownButton<int>(
                  key: BudgetPeriodAppKeys.dropdown,
                  value: selected,
                  isExpanded: true,
                  items: [
                    for (var day = BudgetPeriodService.minClosingDay;
                        day <= BudgetPeriodService.maxClosingDay;
                        day++)
                      DropdownMenuItem<int>(
                        value: day,
                        child: Text(BudgetPeriodService.closingDayLabel(day)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => selected = value);
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  BudgetPeriodService.transitionLabel(selected),
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('キャンセル'),
              ),
              SemanticHelper.interactive(
                testId: 'budgetPeriod_btn_save',
                label: '締め日を保存',
                child: ElevatedButton(
                  key: BudgetPeriodAppKeys.saveButton,
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('保存'),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true) return;

    // 永続化してから、自前で再読込して表示を更新する（state だけ更新しない）。
    await widget.repository.save(selected);
    final reloaded = await widget.repository.load();
    if (!mounted) return;
    setState(() {
      _closingDay = BudgetPeriodService.normalize(reloaded);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final period =
        BudgetPeriodService.periodFor(widget.now(), closingDay: _closingDay);

    return Container(
      key: BudgetPeriodAppKeys.section,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_repeat, color: colorScheme.primary, size: 22),
              const SizedBox(width: 8),
              Text(
                '家計の締め日',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            BudgetPeriodService.closingDayLabel(_closingDay),
            key: BudgetPeriodAppKeys.currentLabel,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            BudgetPeriodService.transitionLabel(_closingDay),
            key: BudgetPeriodAppKeys.transitionLabel,
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            '現在の期間',
            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
          ),
          Text(
            period.label,
            key: BudgetPeriodAppKeys.previewLabel,
            style: TextStyle(fontSize: 13, color: colorScheme.onSurface),
          ),
          Text(
            '${period.days}日間',
            key: BudgetPeriodAppKeys.previewDays,
            style: TextStyle(fontSize: 13, color: colorScheme.onSurface),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: SemanticHelper.interactive(
              testId: 'budgetPeriod_btn_edit',
              label: '締め日を変更',
              child: OutlinedButton(
                key: BudgetPeriodAppKeys.editButton,
                onPressed: _openEditDialog,
                child: const Text('変更'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
