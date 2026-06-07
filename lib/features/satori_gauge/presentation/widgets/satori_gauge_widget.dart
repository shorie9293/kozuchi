import 'package:flutter/material.dart';
import 'package:kozuchi/domain/models/player_model.dart';
import 'package:kozuchi/domain/models/enlightenment_stage.dart';

/// SATORI（悟り）ゲージ表示Widget
///
/// 現在のSATORI値と開眼段階（初転法輪→縁起→空）を表示する。
class SatoriGaugeWidget extends StatelessWidget {
  final PlayerModel player;

  const SatoriGaugeWidget({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final maxSatori = 100.0; // 空到達の閾値を最大値として表示
    final satoriRatio = (player.satori / maxSatori).clamp(0.0, 1.0);
    final stage = player.enlightenmentStage;

    return KeyedSubtree(
      key: const Key('satori_gauge_widget'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ラベル行
          Row(
            children: [
              const Text('🧘 SATORI（悟りゲージ）', style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(
                '${player.satori}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // SATORIバー
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 20,
              child: Stack(
                children: [
                  Container(color: colorScheme.surfaceContainerHighest),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: satoriRatio,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.secondary,
                            colorScheme.tertiary,
                            Colors.amber,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // マイルストーン：縁起
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: EnlightenmentStage.engi.threshold / maxSatori,
                    child: Container(
                      height: 20,
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(color: Colors.white.withValues(alpha: 0.5), width: 1),
                        ),
                      ),
                    ),
                  ),
                  // マイルストーン：空
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: EnlightenmentStage.kuu.threshold / maxSatori,
                    child: Container(
                      height: 20,
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(color: Colors.white.withValues(alpha: 0.8), width: 2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 開眼段階表示
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStageBadge(EnlightenmentStage.shoTenborin, stage, colorScheme),
              _buildStageBadge(EnlightenmentStage.engi, stage, colorScheme),
              _buildStageBadge(EnlightenmentStage.kuu, stage, colorScheme),
            ],
          ),
          const SizedBox(height: 4),
          // 現在の段階の説明
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Text(
                  '現在: ${stage.label}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.secondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    stage.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageBadge(
    EnlightenmentStage targetStage,
    EnlightenmentStage currentStage,
    ColorScheme colorScheme,
  ) {
    final isReached = currentStage.index >= targetStage.index;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isReached ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        targetStage.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isReached ? FontWeight.bold : FontWeight.normal,
          color: isReached ? colorScheme.onPrimaryContainer : colorScheme.outline,
        ),
      ),
    );
  }
}
