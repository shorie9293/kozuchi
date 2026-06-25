import 'dart:math';
import 'package:flutter/material.dart';

/// クエスト達成エフェクト
///
/// 全クエスト達成時に表示される祝福アニメーション。
/// 金色の粒子が舞い上がり、「全クエスト達成！」のテキストが
/// フェードイン＋スケールアニメーションで表示される。
///
/// 単一クエスト達成時にも使用可能（[showAllComplete] = false）。
class QuestAchievementEffect extends StatefulWidget {
  /// 全達成モード（true: 全クエスト達成、false: 単一クエスト達成）
  final bool showAllComplete;

  /// 達成時に獲得したEXP（表示用）
  final int? expGained;

  /// エフェクト完了時のコールバック
  final VoidCallback? onComplete;

  const QuestAchievementEffect({
    super.key,
    this.showAllComplete = true,
    this.expGained,
    this.onComplete,
  });

  @override
  State<QuestAchievementEffect> createState() =>
      _QuestAchievementEffectState();
}

class _QuestAchievementEffectState extends State<QuestAchievementEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  final List<_SparkleParticle> _particles = [];
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    // 粒子を生成
    for (int i = 0; i < 12; i++) {
      _particles.add(_SparkleParticle(
        x: _rng.nextDouble() * 200 - 100,
        delay: _rng.nextDouble() * 0.3,
        size: 4.0 + _rng.nextDouble() * 6.0,
      ));
    }

    _controller.forward().then((_) {
      widget.onComplete?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 粒子エフェクト
              ..._particles.map((p) => _buildParticle(p)),
              // メインテキスト
              Opacity(
                opacity: _fadeAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.amber.shade400,
                          Colors.orange.shade400,
                          Colors.amber.shade400,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('✨', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(
                          widget.showAllComplete
                              ? '全クエスト達成！'
                              : 'クエスト達成！',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (widget.expGained != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            'EXP +${widget.expGained}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                        const SizedBox(width: 6),
                        const Text('✨', style: TextStyle(fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildParticle(_SparkleParticle particle) {
    final progress = (_controller.value - particle.delay).clamp(0.0, 1.0);
    if (progress <= 0) return const SizedBox.shrink();

    final yOffset = -40.0 * progress;
    final opacity = (1.0 - progress).clamp(0.0, 1.0);
    final scale = 1.0 - progress * 0.5;

    return Positioned(
      left: 100 + particle.x,
      bottom: 40 + yOffset,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: Icon(
            Icons.star,
            size: particle.size,
            color: Colors.amber.shade300,
          ),
        ),
      ),
    );
  }
}

/// 粒子データ
class _SparkleParticle {
  final double x;
  final double delay;
  final double size;

  const _SparkleParticle({
    required this.x,
    required this.delay,
    required this.size,
  });
}
