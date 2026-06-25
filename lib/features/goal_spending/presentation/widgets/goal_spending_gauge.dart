import 'package:flutter/material.dart';

/// 目標支出消化率ゲージ
///
/// 月間予算に対する当月支出の消化率をプログレスバーで表示する。
/// 支出すればゲージが上昇（RPGのEXP的）。
///
/// 予算未設定時（monthlyBudget == 0）はタップ可能な設定促しカードを表示。
class GoalSpendingGauge extends StatelessWidget {
  /// 月間予算額（円）。0の場合は未設定扱い
  final int monthlyBudget;

  /// 当月の累積支出額（円）
  final int totalSpent;

  /// 月末までの残日数（今日を含む）
  final int remainingDays;

  /// 予算未設定時のタップコールバック
  final VoidCallback? onTapBudget;

  const GoalSpendingGauge({
    super.key,
    required this.monthlyBudget,
    required this.totalSpent,
    required this.remainingDays,
    this.onTapBudget,
  });

  bool get _isBudgetSet => monthlyBudget > 0;

  int get _remainingBudget {
    final r = monthlyBudget - totalSpent;
    return r < 0 ? 0 : r;
  }

  bool get _isOverBudget => monthlyBudget > 0 && totalSpent > monthlyBudget;

  double get _usagePercent =>
      monthlyBudget > 0 ? (totalSpent / monthlyBudget * 100).clamp(0, 200) : 0;

  int get _dailyAllowance {
    if (remainingDays <= 0) return 0;
    if (_remainingBudget <= 0) return 0;
    return _remainingBudget ~/ remainingDays;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isBudgetSet) {
      return _buildNotSet(context);
    }
    return _buildGauge(context);
  }

  Widget _buildNotSet(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTapBudget,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            const Text('🎯', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '今月の目標支出',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'タップして目標額を設定',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colorScheme.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildGauge(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayPercent = _usagePercent > 100 ? 100.0 : _usagePercent;
    final barColor = _isOverBudget
        ? Colors.red
        : _usagePercent > 80
            ? Colors.orange
            : _usagePercent > 50
                ? Colors.amber
                : Colors.green;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            barColor.withValues(alpha: 0.08),
            barColor.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: barColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // タイトル行
          Row(
            children: [
              const Text('🎯', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                '今月の目標支出',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              if (_isOverBudget)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '⚠️ 予算超過',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // 消化率バー
          _buildProgressBar(barColor, displayPercent),
          const SizedBox(height: 10),
          // 数値グリッド
          _buildStatsGrid(colorScheme, barColor),
        ],
      ),
    );
  }

  Widget _buildProgressBar(Color barColor, double displayPercent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '消化率',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            Text(
              '${_usagePercent.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: barColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: displayPercent / 100.0,
            backgroundColor: barColor.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
            minHeight: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(ColorScheme colorScheme, Color accentColor) {
    return Row(
      children: [
        _buildStatItem(
          '残予算',
          '¥${_format(_remainingBudget)}',
          colorScheme,
          _isOverBudget ? Colors.red : Colors.green,
        ),
        const SizedBox(width: 8),
        _buildStatItem(
          '残日数',
          '$remainingDays日',
          colorScheme,
          accentColor,
        ),
        const SizedBox(width: 8),
        _buildStatItem(
          '月予算',
          '¥${_format(monthlyBudget)}',
          colorScheme,
          colorScheme.primary,
        ),
        const SizedBox(width: 8),
        _buildStatItem(
          '日割',
          '¥${_format(_dailyAllowance)}',
          colorScheme,
          _isOverBudget ? Colors.red : Colors.orange,
        ),
      ],
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    ColorScheme colorScheme,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
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
      ),
    );
  }

  String _format(int amount) {
    if (amount >= 10000) {
      final man = (amount / 10000).toStringAsFixed(1);
      if (man.endsWith('.0')) return '${amount ~/ 10000}万';
      return '${man}万';
    }
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }
}
