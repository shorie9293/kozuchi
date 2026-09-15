import 'package:flutter/material.dart';
import 'package:kozuchi/features/monthly_report/domain/monthly_report.dart';

/// 月次レポートカード（見た目のみ・状態を持たない）
///
/// スクリーンショット映えする固定幅の縦長カード。
class MonthlyReportCardView extends StatelessWidget {
  static const double cardWidth = 360;

  final MonthlyReport report;

  const MonthlyReportCardView({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (report.isEmpty) {
      return Container(
        width: cardWidth,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${report.period.label} 家計レポート',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Text('この月の記録はありません', style: theme.textTheme.bodyLarge),
          ],
        ),
      );
    }

    return Container(
      width: cardWidth,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${report.period.label} 家計レポート',
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _amountRow('収入', _yen(report.totalIncome), theme),
          _amountRow(
            '支出',
            _yen(report.totalExpense),
            theme,
            rowKey: 'monthlyReportTotalExpense',
          ),
          _amountRow(
            '収支',
            (report.balance >= 0 ? '+' : '-') + _yen(report.balance.abs()),
            theme,
            rowKey: 'monthlyReportBalance',
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(report.savingsRateLabel, style: theme.textTheme.bodyMedium),
              Text('前月比 ${report.changeLabel}',
                  style: theme.textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: 16),
          if (report.categories.isNotEmpty) ...[
            Text('TOP3カテゴリ', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final c in report.topCategories(3))
              _categoryBar(c, colorScheme, theme),
          ],
        ],
      ),
    );
  }

  Widget _amountRow(String label, String value, ThemeData theme,
      {String? rowKey}) {
    return Padding(
      key: rowKey == null ? null : Key(rowKey),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyLarge),
          Text(value,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _categoryBar(
    MonthlyReportCategory c,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(c.category, style: theme.textTheme.bodySmall)),
              Text('${c.amount}円 (${(c.ratio * 100).toStringAsFixed(0)}%)',
                  style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: c.ratio,
              minHeight: 8,
              color: colorScheme.primary,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }

  static String _yen(int amount) => '$amount円';
}
