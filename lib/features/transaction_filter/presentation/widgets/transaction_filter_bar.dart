import 'package:flutter/material.dart';
import 'package:kozuchi/features/transaction_filter/domain/models/transaction_filter.dart';

/// 取引履歴フィルタバーウィジェット
///
/// 種別切替（全件/収入/支出）の SegmentedButton と
/// 日付範囲選択（開始日・終了日）のフィールドを提供する。
/// フィルタ値が変更されるたびに onChanged コールバックを発火する。
class TransactionFilterBar extends StatefulWidget {
  /// 初期フィルタ値
  final TransactionFilter initialFilter;

  /// フィルタ変更時に呼ばれるコールバック
  final void Function(TransactionFilter filter) onChanged;

  const TransactionFilterBar({
    super.key,
    this.initialFilter = const TransactionFilter(),
    required this.onChanged,
  });

  @override
  State<TransactionFilterBar> createState() => _TransactionFilterBarState();
}

class _TransactionFilterBarState extends State<TransactionFilterBar> {
  late TransactionFilter _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
  }

  void _updateFilter(TransactionFilter newFilter) {
    if (newFilter == _filter) return;
    setState(() => _filter = newFilter);
    widget.onChanged(newFilter);
  }

  void _onTypeChanged(TransactionFilterType type) {
    if (type == _filter.type) return; // 同じ値なら発火しない
    _updateFilter(_filter.copyWith(type: type));
  }

  Future<void> _pickDate(BuildContext context, bool isStart) async {
    final now = DateTime.now();
    final initialDate = isStart
        ? (_filter.startDate ?? DateTime(now.year, now.month, 1))
        : (_filter.endDate ?? now);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      helpText: isStart ? '開始日を選択' : '終了日を選択',
      cancelText: 'キャンセル',
      confirmText: '決定',
    );

    if (picked != null) {
      final newFilter = isStart
          ? _filter.copyWith(startDate: picked)
          : _filter.copyWith(endDate: picked);
      _updateFilter(newFilter);
    }
  }

  String _dateLabel(DateTime? date) {
    if (date == null) return '----';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 種別切替 ──
          SegmentedButton<TransactionFilterType>(
            segments: TransactionFilterType.values.map((type) {
              return ButtonSegment<TransactionFilterType>(
                value: type,
                label: Text(type.label),
              );
            }).toList(),
            selected: {_filter.type},
            onSelectionChanged: (selected) {
              _onTypeChanged(selected.first);
            },
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: WidgetStateProperty.all(
                const TextStyle(fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // ── 日付範囲 ──
          Row(
            children: [
              // 開始日
              Expanded(
                child: _DateField(
                  key: const Key('startDateField'),
                  label: '開始日',
                  value: _dateLabel(_filter.startDate),
                  onTap: () => _pickDate(context, true),
                ),
              ),
              const SizedBox(width: 8),
              // 終了日
              Expanded(
                child: _DateField(
                  key: const Key('endDateField'),
                  label: '終了日',
                  value: _dateLabel(_filter.endDate),
                  onTap: () => _pickDate(context, false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 日付フィールド（タップで日付ピッカーを開く）
class _DateField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.calendar_today,
              size: 14,
              color: colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}
