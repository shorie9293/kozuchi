import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:kozuchi/features/asset_trend/domain/monthly_asset_point.dart';

/// 月次資産推移の折れ線グラフウィジェット。
///
/// [points] は昇順（古い月 → 新しい月）で渡すこと。
/// 累積残高 [MonthlyAssetPoint.balance] を折れ線で可視化する。
///
/// ```dart
/// AssetTrendChart(
///   points: const AssetTrendService().buildMonthlyTrend(transactions),
/// )
/// ```
class AssetTrendChart extends StatelessWidget {
  /// 月次資産推移（昇順・必須）
  final List<MonthlyAssetPoint> points;

  /// グラフの高さ（デフォルト: 240）
  final double height;

  /// 折れ線の色（デフォルト: テーマの primary）
  final Color? lineColor;

  const AssetTrendChart({
    super.key,
    required this.points,
    this.height = 240,
    this.lineColor,
  });

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return SizedBox(
        key: const Key('asset_trend_chart_empty'),
        height: height,
        child: const Center(child: Text('資産推移データがありません')),
      );
    }

    final theme = Theme.of(context);
    final color = lineColor ?? theme.colorScheme.primary;
    final balances = [for (final p in points) p.balance.toDouble()];
    var maxY = balances.reduce((a, b) => a > b ? a : b);
    var minY = balances.reduce((a, b) => a < b ? a : b);
    if (maxY == minY) {
      maxY += 1;
      minY -= 1;
    }
    final pad = (maxY - minY) * 0.15;
    maxY += pad;
    minY -= pad;

    return SizedBox(
      key: const Key('asset_trend_chart'),
      height: height,
      child: LineChart(
        key: const Key('asset_trend_chart_canvas'),
        LineChartData(
          minX: 0,
          maxX: (points.length - 1).toDouble(),
          minY: minY,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < points.length; i++)
                  FlSpot(i.toDouble(), points[i].balance.toDouble()),
              ],
              isCurved: false,
              barWidth: 3,
              color: color,
              dotData: FlDotData(show: points.length <= 24),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.15),
              ),
            ),
          ],
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
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= points.length) {
                    return const SizedBox.shrink();
                  }
                  // 月数が多い場合は間引いて表示する
                  final step = points.length <= 12 ? 1 : 3;
                  if (index % step != 0 && index != points.length - 1) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      points[index].label,
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 52,
                getTitlesWidget: (value, meta) {
                  if (value == meta.min || value == meta.max) {
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
            getDrawingHorizontalLine: (value) => FlLine(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots.map((spot) {
                final index = spot.x.toInt();
                if (index < 0 || index >= points.length) return null;
                return LineTooltipItem(
                  '${points[index].label}\n¥${_formatAmount(spot.y)}',
                  TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  /// 金額を見やすい文字列に整形
  static String _formatAmount(double value) {
    final negative = value < 0;
    final abs = value.abs();
    final String body;
    if (abs >= 10000) {
      body = '${(abs / 10000).toStringAsFixed(1)}万';
    } else if (abs >= 1000) {
      body = '${(abs / 1000).toStringAsFixed(1)}k';
    } else {
      body = abs.toStringAsFixed(0);
    }
    return negative ? '-$body' : body;
  }
}
