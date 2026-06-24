import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:kozuchi/domain/models/level_stage.dart';

/// 開眼段階の昇格時に表示する全画面アニメーションオーバーレイ
///
/// 2種類のアニメーションを提供:
/// - [LevelStage.engi] 到達時: 曼荼羅展開エフェクト
/// - [LevelStage.kuu] 到達時: 世界反転エフェクト
///
/// 「飛ばす」ボタンで即座にスキップ可能。アニメーション完了後も自動で閉じる。
class EnlightenmentTransitionOverlay extends StatefulWidget {
  /// 到達した開眼段階
  final LevelStage reachedStage;

  /// アニメーション完了またはスキップ時のコールバック
  final VoidCallback onComplete;

  const EnlightenmentTransitionOverlay({
    super.key,
    required this.reachedStage,
    required this.onComplete,
  });

  @override
  State<EnlightenmentTransitionOverlay> createState() =>
      _EnlightenmentTransitionOverlayState();
}

class _EnlightenmentTransitionOverlayState
    extends State<EnlightenmentTransitionOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    // 自動再生開始
    _controller.forward();

    // 完了時に自動で閉じる
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _skip() {
    _controller.stop();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final isEngi = widget.reachedStage == LevelStage.engi;
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 半透明背景
        GestureDetector(
          onTap: () {}, // タップ吸収（背景タップで閉じない）
          child: Container(color: Colors.black87),
        ),
        // アニメーション領域
        Center(
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              if (isEngi) {
                return _buildMandalaUnfolding(colorScheme);
              } else {
                return _buildWorldReversing(colorScheme);
              }
            },
          ),
        ),
        // タイトル
        Positioned(
          top: 120,
          left: 0,
          right: 0,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, _) {
              return Opacity(
                opacity: _animation.value.clamp(0.0, 1.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isEngi ? '🌅 縁起の開眼' : '☸️ 空の開眼',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primaryContainer,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isEngi
                          ? '曼荼羅が展開し、金の流れが縁として見え始める…'
                          : '世界が反転し、「自分の金」という幻が溶けていく…',
                      style: TextStyle(
                        fontSize: 16,
                        color: colorScheme.onPrimaryContainer
                            .withValues(alpha: 0.8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        // 「飛ばす」ボタン
        Positioned(
          bottom: 80,
          left: 0,
          right: 0,
          child: Center(
            child: TextButton(
              onPressed: _skip,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white70,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text(
                '飛ばす ▸',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 曼荼羅展開エフェクト (初転法輪→縁起)
  Widget _buildMandalaUnfolding(ColorScheme colorScheme) {
    final progress = _animation.value;
    final size = 280.0;
    final expandedSize = size * (0.3 + progress * 0.7);

    return SizedBox(
      width: expandedSize,
      height: expandedSize,
      child: CustomPaint(
        painter: _MandalaPainter(
          progress: progress,
          color: colorScheme.tertiary,
          accentColor: Colors.amber,
        ),
      ),
    );
  }

  /// 世界反転エフェクト (縁起→空)
  Widget _buildWorldReversing(ColorScheme colorScheme) {
    final progress = _animation.value;

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateY(progress * 3.14159 * 0.5) // 90度回転
        ..scale(1.0 - progress * 0.3), // やや縮小
      child: Container(
        width: 240,
        height: 240,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              colorScheme.primaryContainer.withValues(alpha: 0.8 * (1.0 - progress)),
              colorScheme.secondaryContainer.withValues(alpha: 0.4 * progress),
              Colors.transparent,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: Center(
          child: Icon(
            Icons.all_inclusive,
            size: 64 * (1.0 + progress * 0.5),
            color: Colors.white.withValues(alpha: 0.6 + progress * 0.4),
          ),
        ),
      ),
    );
  }
}

/// 曼荼羅模様を描画する CustomPainter
class _MandalaPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color accentColor;

  _MandalaPainter({
    required this.progress,
    required this.color,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // 外側のリング（曼荼羅の円）
    final ringCount = 5;
    for (int i = 0; i < ringCount; i++) {
      final ringProgress = (progress * ringCount - i).clamp(0.0, 1.0);
      if (ringProgress <= 0) continue;

      final radius = maxRadius * ((i + 1) / ringCount) * ringProgress;
      final paint = Paint()
        ..color = color.withValues(alpha: 0.3 * ringProgress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(center, radius, paint);
    }

    // 内側の幾何学模様（蓮華の花弁）
    final petalCount = 8;
    for (int i = 0; i < petalCount; i++) {
      final angle = (math.pi * 2 * i / petalCount) + progress * math.pi;
      final petalProgress = (progress * 2 - 0.3).clamp(0.0, 1.0);
      if (petalProgress <= 0) continue;

      final petalLength = maxRadius * 0.6 * petalProgress;
      final dx = center.dx + math.cos(angle) * petalLength * 0.5;
      final dy = center.dy + math.sin(angle) * petalLength * 0.5;

      final petalPaint = Paint()
        ..color = accentColor.withValues(alpha: 0.5 * petalProgress)
        ..style = PaintingStyle.fill;

      final path = Path();
      path.moveTo(center.dx, center.dy);
      path.lineTo(
        dx + math.cos(angle + 0.2) * petalLength * 0.4,
        dy + math.sin(angle + 0.2) * petalLength * 0.4,
      );
      path.lineTo(
        dx + math.cos(angle) * petalLength,
        dy + math.sin(angle) * petalLength,
      );
      path.lineTo(
        dx + math.cos(angle - 0.2) * petalLength * 0.4,
        dy + math.sin(angle - 0.2) * petalLength * 0.4,
      );
      path.close();

      canvas.drawPath(path, petalPaint);

      // 花弁の縁取り
      final strokePaint = Paint()
        ..color = color.withValues(alpha: 0.6 * petalProgress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawPath(path, strokePaint);
    }

    // 中心の光点
    final centerGlow = Paint()
      ..color = accentColor.withValues(alpha: progress)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 6.0 + progress * 4.0, centerGlow);
  }

  @override
  bool shouldRepaint(covariant _MandalaPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
