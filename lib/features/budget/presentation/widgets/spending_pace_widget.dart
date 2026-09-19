import 'package:flutter/material.dart';
import 'package:kozuchi/features/budget/domain/spending_pace.dart';

/// 支出ペースと月末着地予測を表示するウィジェット
///
/// 1日あたりの支出ペース・月末着地見込み・予算比バーを表示し、
/// 予算超過ペースなら警告を促す。
class SpendingPaceWidget extends StatelessWidget {
  /// 支出ペースの計算結果
  final SpendingPace pace;

  /// データ読み込み中かどうか
  final bool isLoading;

  /// レベル表示（絵文字+label）用 Key
  static const Key levelKey = Key('spending_pace_level');

  /// 月末着地見込み用 Key
  static const Key forecastKey = Key('spending_pace_forecast');

  /// 1日あたりペース用 Key
  static const Key paceKey = Key('spending_pace_pace');

  /// 使いすぎ/余裕表示用 Key
  static const Key overPaceKey = Key('spending_pace_over_pace');

  /// 予算使い切り日数表示用 Key
  static const Key emptyDaysKey = Key('spending_pace_empty_days');

  /// 着地見込みバー用 Key
  static const Key forecastBarKey = Key('spending_pace_forecast_bar');

  const SpendingPaceWidget({
    super.key,
    required this.pace,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoadingState(context);
    }

    if (!pace.isBudgetSet) {
      return _buildNotSetState(context);
    }

    return _buildPaceCard(context);
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
        child: Text(
          '月末着地予測には予算設定が必要です',
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildPaceCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final level = pace.level;
    final barColor = _levelColor(level);
    final ratio = pace.projectedUsageRatio.clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // タイトル行: レベル絵文字 + label
            Row(
              key: levelKey,
              children: [
                Text(level.emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(
                  level.label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: barColor,
                  ),
                ),
                const Spacer(),
                Text(
                  '${(pace.projectedUsageRatio * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: barColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // 月末着地見込み
            Text(
              pace.forecastLabel,
              key: forecastKey,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            // 1日あたりペース
            Text(
              pace.paceLabel,
              key: paceKey,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            // 着地見込みの予算比バー
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 6,
                child: LinearProgressIndicator(
                  key: forecastBarKey,
                  value: ratio,
                  backgroundColor: barColor.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                ),
              ),
            ),
            // 使いすぎ / 余裕
            if (pace.overPacePerDay != 0) ...[
              const SizedBox(height: 6),
              Text(
                _overPaceText(),
                key: overPaceKey,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: pace.overPacePerDay > 0 ? Colors.red : Colors.green,
                ),
              ),
            ],
            // 予算使い切り予測
            if (pace.daysUntilBudgetEmpty != null) ...[
              const SizedBox(height: 4),
              Text(
                'このペースだと残り${pace.daysUntilBudgetEmpty}日で予算を使い切ります',
                key: emptyDaysKey,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.red,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _overPaceText() {
    final v = pace.overPacePerDay;
    return v > 0
        ? '1日 ¥${formatAmount(v)} 使いすぎ'
        : '1日 ¥${formatAmount(-v)} 余裕';
  }

  Color _levelColor(SpendingPaceLevel level) => switch (level) {
        SpendingPaceLevel.comfortable => Colors.green,
        SpendingPaceLevel.onTrack => Colors.blue,
        SpendingPaceLevel.caution => Colors.amber,
        SpendingPaceLevel.critical => Colors.orange,
        SpendingPaceLevel.exceeded => Colors.red,
        SpendingPaceLevel.unknown => Colors.grey,
      };
}
