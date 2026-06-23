import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:kozuchi/features/summary_chart/domain/category_pie_data.dart';

/// カテゴリ別支出の円グラフWidget
///
/// [CategoryPieData] のリストを受け取り、
/// fl_chart を用いてインタラクティブな円グラフを表示する。
///
/// 特徴：
/// - タッチでツールチップ表示（カテゴリ名・金額・割合）
/// - 凡例の表示/非表示切替
/// - レスポンシブ対応（LayoutBuilder で親サイズに追従）
/// - テーマカラーに調和した配色
class CategoryPieChartWidget extends StatefulWidget {
  /// 表示データ
  final List<CategoryPieData> data;

  /// グラフ上部に表示するタイトル（nullの場合は非表示）
  final String? title;

  /// 凡例を表示するか（デフォルト: true）
  final bool showLegend;

  /// 各セクションのタッチコールバック
  /// [touchedIndex] がタップされたセクションのインデックス（-1でタッチ解除）
  final void Function(int touchedIndex)? onTouched;

  const CategoryPieChartWidget({
    super.key,
    required this.data,
    this.title,
    this.showLegend = true,
    this.onTouched,
  });

  @override
  State<CategoryPieChartWidget> createState() => _CategoryPieChartWidgetState();
}

class _CategoryPieChartWidgetState extends State<CategoryPieChartWidget> {
  int _touchedIndex = -1;

  /// カテゴリ別の色セット（Material Design の鮮やかな色群）
  static const _colors = [
    Color(0xFF4CAF50), // green
    Color(0xFF2196F3), // blue
    Color(0xFFFF9800), // orange
    Color(0xFFE91E63), // pink
    Color(0xFF9C27B0), // purple
    Color(0xFF00BCD4), // cyan
    Color(0xFFFFEB3B), // yellow
    Color(0xFF795548), // brown
    Color(0xFF607D8B), // blue-grey
    Color(0xFFFF5722), // deep-orange
    Color(0xFF3F51B5), // indigo
    Color(0xFF8BC34A), // light-green
  ];

  Color _getColor(int index) => _colors[index % _colors.length];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.title != null) ...[
          Text(
            widget.title!,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          // デフォルト高さ。LayoutBuilderで親に合わせて調整
          height: 300,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.maxWidth < constraints.maxHeight
                  ? constraints.maxWidth
                  : constraints.maxHeight;
              return Column(
                children: [
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback: (FlTouchEvent event, pieTouchResponse) {
                            if (!event.isInterestedForInteractions ||
                                pieTouchResponse == null ||
                                pieTouchResponse.touchedSection == null) {
                              setState(() => _touchedIndex = -1);
                              widget.onTouched?.call(-1);
                              return;
                            }
                            final index = pieTouchResponse
                                .touchedSection!.touchedSectionIndex;
                            setState(() => _touchedIndex = index);
                            widget.onTouched?.call(index);
                          },
                        ),
                        borderData: FlBorderData(show: false),
                        sectionsSpace: 2,
                        centerSpaceRadius: size * 0.15,
                        sections: _buildSections(theme),
                      ),
                    ),
                  ),
                  if (widget.showLegend && widget.data.isNotEmpty)
                    _buildLegend(theme),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  List<PieChartSectionData> _buildSections(ThemeData theme) {
    return widget.data.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      final isTouched = index == _touchedIndex;
      final radius = isTouched ? 65.0 : 55.0;

      return PieChartSectionData(
        color: _getColor(index),
        value: item.percentage,
        title: isTouched ? '${item.percentage.toStringAsFixed(1)}%' : '',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
          shadows: const [Shadow(blurRadius: 2, color: Colors.black26)],
        ),
        badgeWidget: isTouched
            ? _buildTooltip(item, theme)
            : null,
        badgePositionPercentageOffset: 1.3,
      );
    }).toList();
  }

  Widget _buildTooltip(CategoryPieData item, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.categoryName,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: theme.colorScheme.onSurface,
            ),
          ),
          Text(
            '¥${item.amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            '${item.percentage.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: widget.data.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isSelected = index == _touchedIndex;
          return GestureDetector(
            onTap: () {
              setState(() {
                _touchedIndex = _touchedIndex == index ? -1 : index;
              });
              widget.onTouched?.call(_touchedIndex);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? _getColor(index).withAlpha(40)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _getColor(index),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    item.categoryName,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
