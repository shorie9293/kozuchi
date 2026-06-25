import 'package:flutter/material.dart';
import 'package:kozuchi/domain/models/achievement_api_model.dart';

/// 実績解除ポップアップ
///
/// 実績が解除された際に画面中央に表示される演出付きポップアップ。
/// 5秒後に自動消滅、またはタップで即座に閉じる。
/// 複数実績が同時解除された場合はスタック表示する。
class AchievementUnlockOverlay extends StatefulWidget {
  /// 今回解除された実績のリスト
  final List<AchievementApiModel> unlockedAchievements;

  /// 全実績を閉じた時のコールバック
  final VoidCallback? onDismiss;

  const AchievementUnlockOverlay({
    super.key,
    required this.unlockedAchievements,
    this.onDismiss,
  });

  @override
  State<AchievementUnlockOverlay> createState() =>
      _AchievementUnlockOverlayState();
}

class _AchievementUnlockOverlayState extends State<AchievementUnlockOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _controller.forward();
    _startAutoDismissTimer();
  }

  void _startAutoDismissTimer() {
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      _dismissCurrent();
    });
  }

  void _dismissCurrent() {
    if (_currentIndex < widget.unlockedAchievements.length - 1) {
      // 次の実績を表示
      setState(() => _currentIndex++);
      _controller.reset();
      _controller.forward();
      _startAutoDismissTimer();
    } else {
      // 全実績表示完了 → 閉じる
      _controller.reverse().then((_) {
        widget.onDismiss?.call();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.unlockedAchievements.isEmpty) {
      return const SizedBox.shrink();
    }

    final achievement = widget.unlockedAchievements[_currentIndex];
    final remaining =
        widget.unlockedAchievements.length - _currentIndex - 1;

    return GestureDetector(
      onTap: _dismissCurrent,
      child: Container(
        color: Colors.black54,
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _opacityAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: child,
                ),
              );
            },
            child: _buildUnlockCard(context, achievement, remaining),
          ),
        ),
      ),
    );
  }

  Widget _buildUnlockCard(
      BuildContext context, AchievementApiModel achievement, int remaining) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: cs.surface,
      margin: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // キラキラエフェクト風のアイコン
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.amber.shade100,
                    Colors.amber.shade50,
                    Colors.transparent,
                  ],
                ),
              ),
              child: Text(achievement.icon, style: const TextStyle(fontSize: 48)),
            ),
            const SizedBox(height: 16),

            // 「実績解除！」ヘッダー
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '🏆 実績解除！',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade900,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // タイトル
            Text(
              achievement.title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // 説明
            Text(
              achievement.description,
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),

            // 残り枚数 or 閉じる案内
            if (remaining > 0)
              Text(
                'タップで次へ (あと$remaining件)',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.4),
                ),
              )
            else
              Text(
                'タップで閉じる',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.4),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 実績解除ポップアップを表示するヘルパー
///
/// ```dart
/// showAchievementUnlockPopup(context, newlyUnlockedAchievements);
/// ```
void showAchievementUnlockPopup(
  BuildContext context,
  List<AchievementApiModel> achievements,
) {
  if (achievements.isEmpty) return;

  showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    builder: (_) => AchievementUnlockOverlay(
      unlockedAchievements: achievements,
      onDismiss: () => Navigator.of(context).pop(),
    ),
  );
}
