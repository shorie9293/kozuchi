import 'package:flutter/material.dart';

import 'package:kozuchi/features/transaction_filter/domain/models/transaction_filter.dart';

/// 取引一覧のフィルタバーWidget。
///
/// 種別トグル（全件/収入/支出）と日付範囲選択（開始〜終了）を提供する。
/// ユーザー操作のたびに [onChanged] で新しい [TransactionFilter] を発火する。
///
/// ## 使い方
///
/// ```dart
/// TransactionFilterBar(
///   initialFilter: const TransactionFilter(),
///   onChanged: (filter) => print(filter.type),
/// )
/// ```
///
/// ## アクセシビリティ
///
/// 全操作可能要素に [Semantics] ラベルを付与している。
class TransactionFilterBar extends StatefulWidget {
  /// 初期フィルタ値。
  final TransactionFilter initialFilter;

  /// フィルタ変更時に発火するコールバック。
  /// 種別切替・日付選択のたびに呼ばれる。
  final ValueChanged<TransactionFilter> onChanged;

  const TransactionFilterBar({
    super.key,
    required this.initialFilter,
    required this.onChanged,
  });

  @override
  State<TransactionFilterBar> createState() => _TransactionFilterBarState();
}

class _TransactionFilterBarState extends State<TransactionFilterBar> {
  late TransactionFilterType _type;
  late DateTime? _startDate;
  late DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _type = widget.initialFilter.type;
    _startDate = widget.initialFilter.startDate;
    _endDate = widget.initialFilter.endDate;
  }

  void _emitFilter() {
    widget.onChanged(
      TransactionFilter(
        type: _type,
        startDate: _startDate,
        endDate: _endDate,
      ),
    );
  }

  void _onTypeChanged(TransactionFilterType? value) {
    if (value == null || value == _type) return;
    setState(() => _type = value);
    _emitFilter();
  }

  Future<void> _pickDate({
    required DateTime? initial,
    required ValueChanged<DateTime?> onPicked,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 365)),
      helpText: '日付を選択',
      cancelText: 'キャンセル',
      confirmText: '決定',
    );
    if (picked != null) {
      onPicked(picked);
      _emitFilter();
    }
  }

  /// 日付を YYYY-MM-DD 形式に整形する
  String _formatDate(DateTime? date) {
    if (date == null) return '----';
    final y = date.year.toString();
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withAlpha(128)),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 幅が狭い（〜480px）は縦積み、広ければ横並び
          final isNarrow = constraints.maxWidth < 480;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 種別トグル ──
              Semantics(
                label: '取引種別フィルタ',
                child: SegmentedButton<TransactionFilterType>(
                  segments: const [
                    ButtonSegment(
                      value: TransactionFilterType.all,
                      label: Text('全件'),
                    ),
                    ButtonSegment(
                      value: TransactionFilterType.income,
                      label: Text('収入'),
                      icon: Icon(Icons.add_circle_outline, size: 16),
                    ),
                    ButtonSegment(
                      value: TransactionFilterType.expense,
                      label: Text('支出'),
                      icon: Icon(Icons.remove_circle_outline, size: 16),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: (selected) =>
                      _onTypeChanged(selected.firstOrNull),
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
              // 日付範囲は縦積み時のみスペースを開ける
              if (isNarrow) const SizedBox(height: 8),

              // ── 日付範囲選択 ──
              Semantics(
                label: '日付範囲フィルタ',
                child: Row(
                  children: [
                    Expanded(
                      child: _DateChip(
                        label: _formatDate(_startDate),
                        hint: '開始日',
                        onTap: () => _pickDate(
                          initial: _startDate,
                          onPicked: (d) => setState(() => _startDate = d),
                        ),
                        icon: Icons.calendar_today,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text('〜', style: TextStyle(color: cs.outline)),
                    ),
                    Expanded(
                      child: _DateChip(
                        label: _formatDate(_endDate),
                        hint: '終了日',
                        onTap: () => _pickDate(
                          initial: _endDate,
                          onPicked: (d) => setState(() => _endDate = d),
                        ),
                        icon: Icons.calendar_today,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 日付選択用のタップ可能なチップ。
///
/// 外観は入力欄風で、タップで [showDatePicker] を開く。
class _DateChip extends StatelessWidget {
  final String label;
  final String hint;
  final VoidCallback onTap;
  final IconData icon;

  const _DateChip({
    required this.label,
    required this.hint,
    required this.onTap,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isPlaceholder = label == '----';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.outlineVariant.withAlpha(100)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: cs.outline),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isPlaceholder ? cs.outline : cs.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
