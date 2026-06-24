import 'package:flutter/material.dart';

/// 予算超過接近時の警告バナー
///
/// 月間支出が予算の閾値（デフォルト80%）を超えた場合に表示する。
/// 飢餓ゾーンに入っていることを視覚的に警告する。
class BudgetWarningBanner extends StatelessWidget {
  /// 今月の支出合計（円）
  final int spentAmount;

  /// 月間予算額（円）
  final int budgetAmount;

  /// 達成率（0.0〜1.0+）
  final double ratio;

  /// 警告閾値（例: 0.8）
  final double threshold;

  const BudgetWarningBanner({
    super.key,
    required this.spentAmount,
    required this.budgetAmount,
    required this.ratio,
    required this.threshold,
  });

  /// 警告の深刻度に応じた色を返す
  Color _warningColor(ColorScheme colorScheme) {
    if (ratio >= 1.0) return colorScheme.error;
    if (ratio >= 0.95) return Colors.deepOrange;
    if (ratio >= threshold) return Colors.orange;
    return Colors.amber;
  }

  /// 警告の深刻度に応じたアイコンを返す
  IconData _warningIcon() {
    if (ratio >= 1.0) return Icons.warning_rounded;
    if (ratio >= 0.95) return Icons.report_problem_rounded;
    return Icons.info_outline_rounded;
  }

  /// 警告メッセージを返す
  String _warningMessage() {
    if (ratio >= 1.0) {
      return '予算を超過しました！支出を見直しましょう';
    }
    if (ratio >= 0.95) {
      return '予算まで残りわずかです。注意してください';
    }
    return '予算の${(ratio * 100).toInt()}%を使用しました。そろそろ飢餓ゾーンです';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final warningColor = _warningColor(colorScheme);
    final remaining = budgetAmount - spentAmount;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            warningColor.withValues(alpha: 0.85),
            warningColor.withValues(alpha: 0.55),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: warningColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(_warningIcon(), color: Colors.white, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '⚠️ 飢餓ゾーン警告',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _warningMessage(),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          // 予算残高表示
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '¥${_formatNumber(spentAmount)} / ¥${_formatNumber(budgetAmount)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                remaining >= 0
                    ? '残り ¥${_formatNumber(remaining)}'
                    : '¥${_formatNumber(remaining.abs())} 超過',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }
}
