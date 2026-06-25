import 'package:flutter/material.dart';
import 'package:kozuchi/domain/models/aggregation_result.dart';
import 'package:kozuchi/domain/services/expense_aggregation_service.dart';
import 'package:kozuchi/domain/services/expense_repository.dart';
import 'package:kozuchi/domain/services/expense_repository_impl.dart';
import 'package:kozuchi/features/spending_chart/data/daily_spending_data.dart';
import 'package:kozuchi/features/spending_chart/presentation/widgets/daily_bar_chart_widget.dart';
import 'package:kozuchi/features/summary_chart/domain/category_pie_data.dart';
import 'package:kozuchi/features/summary_chart/presentation/widgets/category_pie_chart_widget.dart';
import 'package:kozuchi/core/widgets/washi_background.dart';

/// 支出サマリー画面
///
/// 週間/月間の支出集計を、円グラフ・棒グラフ・前期間比較で
/// ひとつの画面に統合して表示する。
///
/// 機能:
/// - 週間/月間 切替トグル
/// - 日付ナビゲーション（前後期間の移動）
/// - カテゴリ別円グラフ（CategoryPieChartWidget）
/// - 日別棒グラフ（DailyBarChartWidget、当期/前期比較）
/// - 総支出比較カード
/// - カテゴリ別増減比較
class SummaryScreen extends StatefulWidget {
  /// 支出リポジトリ（テスト時に注入可能）
  final ExpenseRepository? repository;

  const SummaryScreen({
    super.key,
    this.repository,
  });

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  bool _isWeekly = true;
  bool _isLoading = false;
  DateTime _referenceDate = DateTime.now();
  AggregationResult? _result;
  String? _error;

  ExpenseAggregationService get _service => ExpenseAggregationService(
        widget.repository ?? InMemoryExpenseRepository(),
      );

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
      final result = _isWeekly
          ? await _service.getWeeklySummary(_referenceDate)
          : await _service.getMonthlySummary(_referenceDate);

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

  void _goToPrevious() {
    setState(() {
      _referenceDate = _isWeekly
          ? _referenceDate.subtract(const Duration(days: 7))
          : _subtractMonth(_referenceDate);
    });
    _loadData();
  }

  void _goToNext() {
    final now = DateTime.now();
    final nextDate = _isWeekly
        ? _referenceDate.add(const Duration(days: 7))
        : _addMonth(_referenceDate);

    // 未来には進めない
    if (nextDate.isAfter(now)) return;

    setState(() => _referenceDate = nextDate);
    _loadData();
  }

  DateTime _subtractMonth(DateTime date) {
    final year = date.month == 1 ? date.year - 1 : date.year;
    final month = date.month == 1 ? 12 : date.month - 1;
    final day = date.day > 28 ? 28 : date.day; // 月末対策
    return DateTime(year, month, day);
  }

  DateTime _addMonth(DateTime date) {
    final year = date.month == 12 ? date.year + 1 : date.year;
    final month = date.month == 12 ? 1 : date.month + 1;
    final day = date.day > 28 ? 28 : date.day;
    return DateTime(year, month, day);
  }

  bool get _canGoNext {
    final now = DateTime.now();
    final nextDate = _isWeekly
        ? _referenceDate.add(const Duration(days: 7))
        : _addMonth(_referenceDate);
    return !nextDate.isAfter(now);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      key: const Key('summary_screen'),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          key: const Key('summary_back_button'),
        ),
        title: const Text('支出サマリー'),
        centerTitle: true,
      ),
      body: WashiBackground(
        child: _buildBody(colorScheme),
      ),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    if (_isLoading) {
      return const Center(
        key: Key('summary_loading'),
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return _buildErrorState(colorScheme);
    }

    final result = _result;
    if (result == null || result.current.total == 0) {
      return _buildEmptyState(colorScheme);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 期間切替トグル
          _buildToggle(colorScheme),
          const SizedBox(height: 12),

          // 日付ナビゲーション
          _buildDateNavigation(result.period, colorScheme),
          const SizedBox(height: 20),

          // 総支出比較カード
          _buildTotalComparisonCard(result, colorScheme),
          const SizedBox(height: 24),

          // 円グラフ（カテゴリ別）
          _buildPieChartSection(result, colorScheme),
          const SizedBox(height: 24),

          // 棒グラフ（日別）
          _buildBarChartSection(result, colorScheme),
          const SizedBox(height: 24),

          // カテゴリ別増減比較
          _buildCategoryComparisonSection(result, colorScheme),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// 週間/月間 切替トグル
  Widget _buildToggle(ColorScheme colorScheme) {
    return Center(
      child: Container(
        key: const Key('period_toggle'),
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
          color: isSelected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 18,
                color: isSelected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant),
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

  /// 日付ナビゲーション（← 期間ラベル →）
  Widget _buildDateNavigation(PeriodInfo period, ColorScheme colorScheme) {
    final startStr = _formatDateShort(period.start);
    final endStr = _formatDateShort(period.end);
    final label = period.type == 'weekly' ? '週間集計' : '月間集計';

    return Row(
      key: const Key('date_navigation'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          key: const Key('nav_previous'),
          icon: const Icon(Icons.chevron_left),
          onPressed: _goToPrevious,
          tooltip: '前の期間',
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '$startStr 〜 $endStr',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          key: const Key('nav_next'),
          icon: Icon(
            Icons.chevron_right,
            color: _canGoNext ? null : colorScheme.outline,
          ),
          onPressed: _canGoNext ? _goToNext : null,
          tooltip: '次の期間',
        ),
      ],
    );
  }

  /// 総支出比較カード
  Widget _buildTotalComparisonCard(
    AggregationResult result,
    ColorScheme colorScheme,
  ) {
    final comparison = result.comparison;
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
                child:
                    Icon(Icons.arrow_forward, size: 20, color: colorScheme.outline),
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
          Row(
            children: [
              const Text('差額: ', style: TextStyle(fontSize: 13)),
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
        Text(label,
            style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.6))),
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

  /// カテゴリ別円グラフセクション
  Widget _buildPieChartSection(
    AggregationResult result,
    ColorScheme colorScheme,
  ) {
    final pieData = result.current.byCategory
        .map((c) => CategoryPieData(
              categoryName: c.category,
              amount: c.amount.toDouble(),
              percentage: c.percentage,
            ))
        .toList();

    if (pieData.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      key: const Key('pie_chart_section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'カテゴリ別支出',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        CategoryPieChartWidget(
          data: pieData,
          showLegend: true,
        ),
      ],
    );
  }

  /// 日別棒グラフセクション
  Widget _buildBarChartSection(
    AggregationResult result,
    ColorScheme colorScheme,
  ) {
    final isWeek = result.period.type == 'weekly';
    final currentBars = _toDailySpendingData(result.current.byDay, isWeek);
    final previousBars = _toDailySpendingData(result.previous.byDay, isWeek);

    if (currentBars.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      key: const Key('bar_chart_section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isWeek ? '日別支出（週間）' : '日別支出（月間）',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        DailyBarChartWidget(
          currentPeriod: currentBars,
          previousPeriod: previousBars.isNotEmpty ? previousBars : null,
          key: const Key('daily_bar_chart'),
        ),
      ],
    );
  }

  /// DailyTotal のリストを DailySpendingData に変換
  List<DailySpendingData> _toDailySpendingData(
    List<DailyTotal> dailyTotals,
    bool isWeekly,
  ) {
    const weekDayLabels = ['月', '火', '水', '木', '金', '土', '日'];

    return dailyTotals.map((d) {
      final label = isWeekly
          ? weekDayLabels[d.date.weekday - 1] // weekday: 1=Mon
          : '${d.date.day}';
      return DailySpendingData(day: label, amount: d.amount.toDouble());
    }).toList();
  }

  /// カテゴリ別増減比較セクション
  Widget _buildCategoryComparisonSection(
    AggregationResult result,
    ColorScheme colorScheme,
  ) {
    final changes = result.comparison.byCategoryChanges;
    if (changes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      key: const Key('category_comparison_section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'カテゴリ別 増減比較',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        ...changes.map((cat) => _buildCategoryComparisonCard(cat, colorScheme)),
      ],
    );
  }

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
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              cat.category,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '¥${cat.currentAmount}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  '(前期: ¥${cat.previousAmount})',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: changeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isIncrease
                      ? Icons.trending_up
                      : isDecrease
                          ? Icons.trending_down
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
    );
  }

  /// エラー状態表示
  Widget _buildErrorState(ColorScheme colorScheme) {
    return Center(
      key: const Key('summary_error'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
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
      key: const Key('summary_empty'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: colorScheme.outline),
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

  /// 日付を短縮表示（M/d形式）
  String _formatDateShort(DateTime date) {
    return '${date.month}/${date.day}';
  }
}
