import 'package:flutter/material.dart';
import 'package:kozuchi/features/budget/domain/daily_budget.dart';

/// 日割り予算表示ウィジェット
///
/// 月間予算・当月支出・残予算・残日数・1日あたり使用可能額を
/// 数値と簡易グラフでコンパクトに表示する。
class DailyBudgetWidget extends StatelessWidget {
  /// 日割り予算データ
  final DailyBudget dailyBudget;

  /// データ読み込み中かどうか
  final bool isLoading;

  const DailyBudgetWidget({
    super.key,
    required this.dailyBudget,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoadingState(context);
    }

    if (dailyBudget.isBudgetNotSet) {
      return _buildNotSetState(context);
    }

    return _buildBudgetCard(context);
  }

  Widget _buildLoadingState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotSetState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('📊', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(
                  '日割り予算',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '予算が未設定です。「💵 予算」から設定してください',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final budget = dailyBudget;
    final usagePercent = budget.budgetUsagePercent;
    final isOver = budget.isOverBudget;

    // バーの色: 予算消化率に応じて緑→黄→赤
    final barColor = isOver
        ? Colors.red
        : usagePercent > 80
            ? Colors.orange
            : usagePercent > 50
                ? Colors.amber
                : Colors.green;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // タイトル行
            Row(
              children: [
                const Text('📊', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(
                  '日割り予算',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                // 日割り額を強調表示
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: barColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '¥${_formatAmount(budget.dailyAllowance)}/日',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: barColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 予算消化バー
            _buildUsageBar(barColor, usagePercent, isOver),
            const SizedBox(height: 8),

            // 数値グリッド（2行×2列）
            _buildStatsGrid(budget, colorScheme, barColor),
          ],
        ),
      ),
    );
  }

  /// 予算消化率バー
  Widget _buildUsageBar(Color barColor, double percent, bool isOver) {
    // バーの表示用割合（最大100%）
    final displayPercent = percent > 100 ? 100.0 : percent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isOver ? '⚠️ 予算超過' : '予算消化率',
              style: TextStyle(
                fontSize: 11,
                color: isOver ? Colors.red : Colors.grey.shade600,
              ),
            ),
            Text(
              '${percent.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: barColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: displayPercent / 100.0,
            backgroundColor: barColor.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  /// 数値グリッド（残予算 / 残日数 / 月予算 / 当月支出）
  Widget _buildStatsGrid(
      DailyBudget budget, ColorScheme colorScheme, Color accentColor) {
    return Row(
      children: [
        Expanded(
          child: _buildStatItem(
            label: '残予算',
            value: '¥${_formatAmount(budget.remainingBudget)}',
            colorScheme: colorScheme,
            accentColor: budget.isOverBudget ? Colors.red : Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatItem(
            label: '残日数',
            value: '${budget.remainingDays}日',
            colorScheme: colorScheme,
            accentColor: accentColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatItem(
            label: '月予算',
            value: '¥${_formatAmount(budget.monthlyBudget)}',
            colorScheme: colorScheme,
            accentColor: colorScheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatItem(
            label: '当月支出',
            value: '¥${_formatAmount(budget.totalSpent)}',
            colorScheme: colorScheme,
            accentColor: budget.isOverBudget ? Colors.red : Colors.orange,
          ),
        ),
      ],
    );
  }

  /// 1つの統計項目
  Widget _buildStatItem({
    required String label,
    required String value,
    required ColorScheme colorScheme,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 金額のフォーマット（3桁カンマ区切り）
  String _formatAmount(int amount) {
    if (amount >= 10000) {
      final man = (amount / 10000).toStringAsFixed(1);
      // 末尾が.0の場合は整数表示
      if (man.endsWith('.0')) {
        return '${amount ~/ 10000}万';
      }
      return '${man}万';
    }
    return amount.toString();
  }
}
