import 'package:flutter/material.dart';
import 'package:kozuchi/domain/models/player_model.dart';

/// HPバー（残高）表示Widget
///
/// 現在の残高（HP）と生活防衛ライン、予算達成率ラインを表示する。
/// ピンチ状態（残高≦30,000円）の場合は警告を表示する。
class HpBarWidget extends StatelessWidget {
  final PlayerModel player;

  /// 今月の予算額（円、0の場合は予算未設定として達成率ラインを非表示）
  final int budgetAmount;

  /// 今月の累積支出額（円）
  final int monthlyExpenditure;

  const HpBarWidget({
    super.key,
    required this.player,
    this.budgetAmount = 0,
    this.monthlyExpenditure = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final maxHp = 100000; // 最大HP（表示スケール用）
    final hpRatio = (player.hp / maxHp).clamp(0.0, 1.0);
    final defenseRatio =
        (PlayerModel.livingDefenseLine / maxHp).clamp(0.0, 1.0);

    // 予算達成率ラインの位置（0.0〜1.0）
    final hasBudget = budgetAmount > 0;
    final budgetAchievementRatio = hasBudget
        ? (monthlyExpenditure / budgetAmount).clamp(0.0, 1.0)
        : 0.0;

    return KeyedSubtree(
      key: const Key('hp_bar_widget'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ラベル行
          Row(
            children: [
              const Text('💰 残高（HP）',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(
                '¥${_formatNumber(player.hp)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // HPバー
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 24,
                  child: Stack(
                    children: [
                      // 背景
                      Container(color: colorScheme.surfaceContainerHighest),
                      // HP部分
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: hpRatio,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                colorScheme.primary,
                                player.isPinchState
                                    ? colorScheme.error
                                    : colorScheme.tertiary,
                              ],
                            ),
                          ),
                        ),
                      ),
                      // 生活防衛ライン
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: defenseRatio,
                        child: Container(
                          height: 24,
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(
                                color: colorScheme.error,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // 予算達成率ライン（予算設定済みの場合のみ表示）
                      if (hasBudget)
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: budgetAchievementRatio,
                          child: Container(
                            height: 24,
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(
                                  color: Colors.amber.shade700,
                                  width: 2.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // 凡例行
          Row(
            children: [
              // 生活防衛ライン
              Text(
                '生活防衛 ¥${_formatNumber(PlayerModel.livingDefenseLine)}',
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.outline,
                ),
              ),
              if (hasBudget) ...[
                const SizedBox(width: 12),
                // 予算達成率
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.amber.shade700,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '予算 ${(budgetAchievementRatio * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.amber.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const Spacer(),
              if (player.isPinchState)
                Text(
                  '⚠️ ピンチ状態',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.error,
                    fontWeight: FontWeight.bold,
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
