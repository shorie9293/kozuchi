import 'package:flutter/material.dart';
import 'package:kozuchi/domain/models/player_model.dart';

/// 餓鬼ゾーン警告バナー
///
/// 画面上部に表示する警告バナー。
/// 守護神の名前とともに「餓鬼ゾーンに入っておるぞ」の警告を表示する。
class GakiZoneWarningBanner extends StatelessWidget {
  /// プレイヤーモデル
  final PlayerModel player;

  const GakiZoneWarningBanner({
    super.key,
    required this.player,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final deity = player.guardianDeity;
    final emoji = deity?.emoji ?? '👹';
    final name = deity?.label ?? '守護神';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.red.shade800,
            Colors.orange.shade700,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$nameの警告: 餓鬼ゾーンに入っておるぞ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: colorScheme.onErrorContainer,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'SATORIが低下している…執着を手放せ',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onErrorContainer.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
