import 'package:flutter/material.dart';
import 'package:kozuchi/domain/models/player_model.dart';

/// HPバー（残高）表示Widget
///
/// 現在の残高（HP）と生活防衛ラインを表示する。
/// ピンチ状態（残高≦30,000円）の場合は警告を表示する。
class HpBarWidget extends StatelessWidget {
  final PlayerModel player;

  const HpBarWidget({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final maxHp = 100000; // 最大HP（表示スケール用）
    final hpRatio = (player.hp / maxHp).clamp(0.0, 1.0);
    final defenseRatio = (PlayerModel.livingDefenseLine / maxHp).clamp(0.0, 1.0);

    return KeyedSubtree(
      key: const Key('hp_bar_widget'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ラベル行
          Row(
            children: [
              const Text('💰 残高（HP）', style: TextStyle(fontWeight: FontWeight.bold)),
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
                                player.isPinchState ? colorScheme.error : colorScheme.tertiary,
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
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // 生活防衛ライン表示
          Row(
            children: [
              Text(
                '生活防衛ライン ¥${_formatNumber(PlayerModel.livingDefenseLine)}',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.outline,
                ),
              ),
              const Spacer(),
              if (player.isPinchState)
                Text(
                  '⚠️ ピンチ状態 — 執着の餓えに気をつけよ',
                  style: TextStyle(
                    fontSize: 12,
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
