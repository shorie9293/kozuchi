import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:kozuchi/features/spending_chart/data/daily_spending_data.dart';

/// 日別支出棒グラフウィジェット
///
/// 週間または月間の日別支出を可視化する。
/// 当期と前期の比較表示に対応。
///
/// ```dart
/// DailyBarChartWidget(
///   currentPeriod: [
///     DailySpendingData(day: '月', amount: 1200),
///     DailySpendingData(day: '火', amount: 3400),
///     ...
///   ],
///   previousPeriod: [
///     DailySpendingData(day: '月', amount: 1500),
///     ...
///   ],
///   label: '今週の支出',
/// )
/// ```
class DailyBarChartWidget extends StatelessWidget {
  /// 当期の日別支出データ（必須）
  final List<DailySpendingData> currentPeriod;

  /// 前期の日別支出データ（任意、比較表示用）
  final List<DailySpendingData>? previousPeriod;

  /// グラフのタイトルラベル
  final String? label;

  /// グラフの高さ（デフォルト: 250）
  final double height;

  /// 当期の棒の色（デフォルト: 深紫）
  final Color? currentBarColor;

  /// 前期の棒の色（デフォルト: 半透明の紫）
  final Color? previousBarColor;

  const DailyBarChartWidget({
    super.key,
    required this.currentPeriod,
    this.previousPeriod,
    this.label,
    this.height = 250,
    this.currentBarColor,
    this.previousBarColor,
  });

  @override
  Widget build(BuildContext context) {
    if (currentPeriod.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final defaultCurrentColor = theme.colorScheme.primary;
    final defaultPreviousColor =
        theme.colorScheme.primary.withValues(alpha: 0.35);

    final curColor = currentBarColor ?? defaultCurrentColor;
    final prevColor = previousBarColor ?? defaultPreviousColor;

    return SizedBox(
      key: const Key('daily_bar_chart'),
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                label!,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          Expanded(
            child: BarChart(
              _buildData(curColor, prevColor, theme.colorScheme),
              key: const Key('daily_bar_chart_canvas'),
            ),
          ),
          // 凡例
          if (previousPeriod != null && previousPeriod!.isNotEmpty)
            _buildLegend(context, curColor, prevColor),
        ],
      ),
    );
  }

  BarChartData _buildData(Color curColor, Color prevColor, ColorScheme cs) {
    final hasComparison =
        previousPeriod != null && previousPeriod!.isNotEmpty;
    final maxAmount = _calculateMaxY();

    // 前期データを日ラベルでルックアップ可能なマップに変換
    final previousMap = <String, double>{};
    if (hasComparison) {
      for (final data in previousPeriod!) {
        previousMap[data.day] = data.amount;
      }
    }

    return BarChartData(
      alignment: BarChartAlignment.center,
      groupsSpace: 8,
      maxY: maxAmount * 1.15, // 上部に余白
      minY: 0,
      barGroups: List.generate(currentPeriod.length, (i) {
        final data = currentPeriod[i];
        final prevAmount = previousMap[data.day];
        final rods = <BarChartRodData>[
          // 当期の棒
          BarChartRodData(
            toY: data.amount,
            color: curColor,
            width: hasComparison ? 12 : 18,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
        ];

        // 前期があれば追加の棒
        if (hasComparison) {
          rods.add(
            BarChartRodData(
              toY: prevAmount ?? 0,
              color: prevColor,
              width: 12,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          );
        }

        return BarChartGroupData(
          x: i,
          barRods: rods,
          barsSpace: 4,
        );
      }),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= currentPeriod.length) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  currentPeriod[index].day,
                  style: const TextStyle(fontSize: 11),
                ),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          axisNameWidget: const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text('¥', style: TextStyle(fontSize: 11)),
          ),
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 44,
            interval: _calculateYInterval(maxAmount),
            getTitlesWidget: (value, meta) {
              if (value == meta.max || value == 0) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  _formatAmount(value),
                  style: const TextStyle(fontSize: 10),
                ),
              );
            },
          ),
        ),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: _calculateYInterval(maxAmount),
        getDrawingHorizontalLine: (value) => FlLine(
          color: cs.outlineVariant.withValues(alpha: 0.3),
          strokeWidth: 1,
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border(
          bottom: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
          left: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      barTouchData: BarTouchData(
        enabled: true,
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final dayLabel = currentPeriod[group.x].day;
            if (rodIndex == 0) {
              return BarTooltipItem(
                '$dayLabel\n¥${_formatAmount(rod.toY)}',
                TextStyle(
                  color: curColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            }
            // Previous period tooltip
            return BarTooltipItem(
              '$dayLabel (前期)\n¥${_formatAmount(rod.toY)}',
              TextStyle(
                color: prevColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            );
          },
        ),
      ),
    );
  }

  /// 凡例の表示
  Widget _buildLegend(BuildContext context, Color curColor, Color prevColor) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _legendItem(curColor, '当期'),
          const SizedBox(width: 16),
          _legendItem(prevColor, '前期'),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  /// 支出データから最大Y値を計算
  double _calculateMaxY() {
    double max = 0;
    for (final data in currentPeriod) {
      if (data.amount > max) max = data.amount;
    }
    if (previousPeriod != null) {
      for (final data in previousPeriod!) {
        if (data.amount > max) max = data.amount;
      }
    }
    if (max == 0) return 1000; // デフォルトスケール
    return max;
  }

  /// Y軸の刻み幅を計算（見やすい値に丸める）
  double _calculateYInterval(double maxAmount) {
    if (maxAmount <= 0) return 500;
    // 最大値を4〜6分割する刻み幅を計算
    final rawInterval = maxAmount / 5;
    // 見やすい値に丸める（1, 2, 5, 10, 20, 50, 100, ...）
    final magnitude = _pow10(rawInterval);
    final normalized = rawInterval / magnitude;
    final double nice;
    if (normalized <= 1) {
      nice = 1.0;
    } else if (normalized <= 2) {
      nice = 2.0;
    } else if (normalized <= 5) {
      nice = 5.0;
    } else {
      nice = 10.0;
    }
    return nice * magnitude;
  }

  double _pow10(double value) {
    if (value <= 0) return 1;
    var magnitude = 1.0;
    while (magnitude * 10 <= value) {
      magnitude *= 10;
    }
    return magnitude;
  }

  /// 金額を見やすい文字列に整形
  static String _formatAmount(double value) {
    if (value >= 10000) {
      return '${(value / 10000).toStringAsFixed(1)}万';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return value.toStringAsFixed(0);
  }
}
