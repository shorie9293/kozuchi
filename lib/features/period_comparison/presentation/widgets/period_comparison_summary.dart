import 'package:flutter/material.dart';
import 'package:kozuchi/domain/models/aggregation_result.dart';
import 'package:kozuchi/domain/services/expense_aggregation_service.dart';
import 'package:kozuchi/domain/services/expense_repository.dart';
import 'package:kozuchi/domain/services/expense_repository_impl.dart';

/// 期間比較サマリーウィジェット
///
/// 週間/月間の支出集計を表示し、前期間との差額・増減率を
/// サマリーカード形式で可視化する。
///
/// [ExpenseRepository] を注入することで、
/// テスト時には InMemoryExpenseRepository を渡せる。
/// null の場合は InMemoryExpenseRepository が使われる。
class PeriodComparisonSummary extends StatefulWidget {
  final ExpenseRepository? repository;

  const PeriodComparisonSummary({
    super.key,
    this.repository,
  });

  @override
  State<PeriodComparisonSummary> createState() =>
      _PeriodComparisonSummaryState();
}

class _PeriodComparisonSummaryState extends State<PeriodComparisonSummary> {
  bool _isWeekly = true;
  bool _isLoading = false;
  AggregationResult? _result;
  String? _error;

  ExpenseAggregationService get _service =>
      ExpenseAggregationService(
          widget.repository ?? InMemoryExpenseRepository());

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final now = DateTime.now();
      final result = _isWeekly
          ? await _service.getWeeklySummary(now)
          : await _service.getMonthlySummary(now);

      if (mounted) {
        setState(() {
          _result = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _togglePeriod(bool weekly) {
    if (weekly == _isWeekly) return;
    setState(() => _isWeekly = weekly);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 期間切り替えトグル
        _buildToggle(colorScheme),
        const SizedBox(height: 16),

        // コンテンツ領域
        if (_isLoading)
          const Center(
            key: Key('period_comparison_loading'),
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_error != null)
          _buildErrorState(colorScheme)
        else if (_result == null || _result!.current.total == 0)
          _buildEmptyState(colorScheme)
        else
          _buildSummaryCards(colorScheme),
      ],
    );
  }

  /// 週間/月間 切り替えトグル
  Widget _buildToggle(ColorScheme colorScheme) {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _toggleChip(
              label: '週間',
              icon: Icons.calendar_view_week,
              isSelected: _isWeekly,
              onTap: () => _togglePeriod(true),
              colorScheme: colorScheme,
            ),
            const SizedBox(width: 4),
            _toggleChip(
              label: '月間',
              icon: Icons.calendar_month,
              isSelected: !_isWeekly,
              onTap: () => _togglePeriod(false),
              colorScheme: colorScheme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggleChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? colorScheme.onPrimary
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// エラー状態表示
  Widget _buildErrorState(ColorScheme colorScheme) {
    return Center(
      key: const Key('period_comparison_error'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.error_outline,
                size: 48, color: colorScheme.error),
            const SizedBox(height: 12),
            Text(
              'データの取得に失敗しました',
              style: TextStyle(color: colorScheme.error),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('再試行'),
            ),
          ],
        ),
      ),
    );
  }

  /// データなし状態表示
  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      key: const Key('period_comparison_empty'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.inbox_outlined,
                size: 48, color: colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              'この期間の支出データはありません',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(
              '支出を記録すると、ここに集計が表示されます',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// サマリーカード群の構築
  Widget _buildSummaryCards(ColorScheme colorScheme) {
    final result = _result!;
    final comparison = result.comparison;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 期間表示ラベル
        _buildPeriodLabel(result.period, colorScheme),
        const SizedBox(height: 12),

        // 総支出比較カード
        _buildTotalComparisonCard(result, comparison, colorScheme),
        const SizedBox(height: 16),

        // カテゴリ別比較カード
        if (comparison.byCategoryChanges.isNotEmpty) ...[
          Text(
            'カテゴリ別比較',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          ...comparison.byCategoryChanges.map(
            (cat) => _buildCategoryComparisonCard(cat, colorScheme),
          ),
        ],
      ],
    );
  }

  /// 期間ラベル
  Widget _buildPeriodLabel(PeriodInfo period, ColorScheme colorScheme) {
    final startStr = _formatDateShort(period.start);
    final endStr = _formatDateShort(period.end);
    final label = period.type == 'weekly' ? '週間集計' : '月間集計';

    return Row(
      children: [
        Icon(
          period.type == 'weekly'
              ? Icons.calendar_view_week
              : Icons.calendar_month,
          size: 16,
          color: colorScheme.primary,
        ),
        const SizedBox(width: 6),
        Text(
          '$label: $startStr 〜 $endStr',
          style: TextStyle(
            fontSize: 13,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// 総支出比較カード
  Widget _buildTotalComparisonCard(
    AggregationResult result,
    PeriodComparison comparison,
    ColorScheme colorScheme,
  ) {
    final currentTotal = result.current.total;
    final previousTotal = result.previous.total;
    final isIncrease = comparison.totalChange > 0;
    final isDecrease = comparison.totalChange < 0;
    final changeSign = comparison.totalChange >= 0 ? '+' : '';
    final changeColor = isIncrease
        ? Colors.red.shade400
        : isDecrease
            ? Colors.green.shade400
            : colorScheme.onSurfaceVariant;

    return Container(
      key: const Key('total_comparison_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.6),
            colorScheme.secondaryContainer.withValues(alpha: 0.4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet, size: 20),
              const SizedBox(width: 8),
              Text(
                '総支出',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              // 増減バッジ
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: changeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isIncrease
                          ? Icons.trending_up
                          : isDecrease
                              ? Icons.trending_down
                              : Icons.trending_flat,
                      size: 16,
                      color: changeColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$changeSign${comparison.totalChangePercent.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: changeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 当期・前期の金額表示
          Row(
            children: [
              Expanded(
                child: _amountBlock(
                  label: '当期',
                  amount: currentTotal,
                  color: colorScheme.onSurface,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward,
                    size: 20, color: colorScheme.outline),
              ),
              Expanded(
                child: _amountBlock(
                  label: '前期',
                  amount: previousTotal,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 差額
          Row(
            children: [
              const Text('差額: ',
                  style: TextStyle(fontSize: 13)),
              Text(
                '$changeSign¥${comparison.totalChange.abs().toString()}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: changeColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _amountBlock({
    required String label,
    required int amount,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '¥${amount.toString()}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: color,
          ),
        ),
      ],
    );
  }

  /// カテゴリ別比較カード
  Widget _buildCategoryComparisonCard(
    CategoryComparison cat,
    ColorScheme colorScheme,
  ) {
    final isIncrease = cat.change > 0;
    final isDecrease = cat.change < 0;
    final changeSign = cat.change >= 0 ? '+' : '';
    final changeColor = isIncrease
        ? Colors.red.shade400
        : isDecrease
            ? Colors.green.shade400
            : colorScheme.onSurfaceVariant;

    return Container(
      key: Key('category_card_${cat.category}'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // カテゴリ名 + 増減率
          Row(
            children: [
              Text(
                cat.category,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: changeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isIncrease
                          ? Icons.arrow_upward
                          : isDecrease
                              ? Icons.arrow_downward
                              : Icons.remove,
                      size: 14,
                      color: changeColor,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '$changeSign${cat.changePercent.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: changeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 金額比較バー
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '当期',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '¥${cat.currentAmount.toString()}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '→',
                  style: TextStyle(
                    fontSize: 16,
                    color: colorScheme.outline,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '前期',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '¥${cat.previousAmount.toString()}',
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              // 差額
              Text(
                '$changeSign¥${cat.change.abs()}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: changeColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 日付を "M/d" 形式に整形
  static String _formatDateShort(DateTime d) =>
      '${d.month}/${d.day}';
}
