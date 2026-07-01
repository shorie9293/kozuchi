import 'dart:math';

import 'package:flutter/material.dart';
import 'package:kozuchi/features/effects/domain/effect_instance.dart';

/// SATORI増加時の光の粒子エフェクト
///
/// SATORI値が増加した際に、指定位置から光の粒子が上昇する演出を行う。
/// 各粒子はランダムな水平ドリフトと上昇速度で飛翔し、
/// 徐々にフェードアウトする。粒子の背後に金色の光彩が広がる。
///
/// 持続時間は [EffectInstance.definition.duration]（デフォルト1.5秒）。
/// 粒子数は [EffectInstance.definition.particleCount]（デフォルト16）。
///
/// 使用例（EffectManagerのeffectBuilder内）:
/// ```dart
/// 'satori_increase' => SatoriIncreaseEffect(instance: instance),
/// ```
class SatoriIncreaseEffect extends StatefulWidget {
  final EffectInstance instance;
  const SatoriIncreaseEffect({super.key, required this.instance});

  @override
  State<SatoriIncreaseEffect> createState() => _SatoriIncreaseEffectState();
}

class _SatoriIncreaseEffectState extends State<SatoriIncreaseEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;
  late final List<_LightParticle> _particles;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.instance.definition.duration,
      vsync: this,
    );
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _particles = _generateParticles(
      widget.instance.definition.particleCount ?? 16,
    );
    _controller.forward();
  }

  List<_LightParticle> _generateParticles(int count) {
    final particles = <_LightParticle>[];
    for (var i = 0; i < count; i++) {
      // ランダムな水平ドリフト (-40〜40px)
      final driftX = (_random.nextDouble() - 0.5) * 80.0;
      // ランダムな上昇距離 (60〜160px)
      final riseY = 60.0 + _random.nextDouble() * 100.0;
      // ランダムなサイズ (5〜14px、大きめ)
      final size = 5.0 + _random.nextDouble() * 9.0;
      // ランダムな開始遅延 (0〜0.3秒相当のprogress)
      final delay = _random.nextDouble() * 0.2;
      // ランダムな色のバリエーション（金色〜白金色）
      final colorVariants = [
        const Color(0xFFFFF8DC), // コーンスィルク
        const Color(0xFFFFD700), // ゴールド
        const Color(0xFFFFE4B5), // モカシン
        const Color(0xFFFFFACD), // レモンシフォン
      ];
      final color = colorVariants[_random.nextInt(colorVariants.length)];

      particles.add(_LightParticle(
        driftX: driftX,
        riseY: riseY,
        size: size,
        delay: delay,
        color: color,
      ));
    }
    return particles;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, child) {
        return Stack(
          children: [
            // 粒子の背後に広がる光彩
            ..._buildBackgroundGlow(),
            // 粒子
            ..._particles.map((particle) {
              // 遅延を考慮した進行度
              final effectiveProgress =
                  ((_progress.value - particle.delay) / (1.0 - particle.delay))
                      .clamp(0.0, 1.0);
              // 上昇は easeOut でゆっくり減速
              final riseCurve = Curves.easeOutCubic.transform(effectiveProgress);
              final dx = particle.driftX * effectiveProgress;
              final dy = -particle.riseY * riseCurve;
              // フェードアウト：後半0.5から減衰
              final opacity = effectiveProgress < 0.5
                  ? 1.0
                  : 1.0 - ((effectiveProgress - 0.5) / 0.5);
              // スケール：開始時1.8倍から徐々に縮小
              final scale = 1.8 - 0.8 * effectiveProgress;

              return Positioned(
                left: widget.instance.position.dx + dx - particle.size / 2,
                top: widget.instance.position.dy + dy - particle.size / 2,
                child: IgnorePointer(
                  child: Transform.scale(
                    scale: scale.clamp(1.0, 1.8),
                    child: Opacity(
                      opacity: opacity.clamp(0.0, 1.0),
                      child: Container(
                        width: particle.size,
                        height: particle.size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            center: Alignment(0.0, 0.0),
                            radius: 1.0,
                            colors: [
                              particle.color,
                              particle.color.withValues(alpha: 0.6),
                              particle.color.withValues(alpha: 0.0),
                            ],
                            stops: const [0.0, 0.3, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  /// 粒子の背後に広がる金色の光彩を生成する
  List<Widget> _buildBackgroundGlow() {
    final glowProgress = _progress.value;
    // 0〜0.3で出現、0.3〜0.7で維持、0.7〜1.0で消滅
    final glowOpacity = glowProgress < 0.3
        ? glowProgress / 0.3 * 0.3
        : glowProgress < 0.7
            ? 0.3
            : 0.3 * (1.0 - (glowProgress - 0.7) / 0.3);
    final glowRadius = 15.0 + glowProgress * 50.0;

    return [
      Positioned(
        left: widget.instance.position.dx - glowRadius,
        top: widget.instance.position.dy - glowRadius,
        child: IgnorePointer(
          child: Opacity(
            opacity: glowOpacity.clamp(0.0, 0.3),
            child: Container(
              width: glowRadius * 2,
              height: glowRadius * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.0,
                  colors: [
                    const Color(0xFFFFD700).withValues(alpha: 0.5),
                    const Color(0xFFFFA500).withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.3, 1.0],
                ),
              ),
            ),
          ),
        ),
      ),
    ];
  }
}

/// 1粒の光の粒子
class _LightParticle {
  /// 水平方向のドリフト距離（px）
  final double driftX;

  /// 上昇距離（px、負値で上方向）
  final double riseY;

  /// 粒子のサイズ（px）
  final double size;

  /// 開始遅延（progress値の割合、0.0〜0.2）
  final double delay;

  /// 粒子の色
  final Color color;

  const _LightParticle({
    required this.driftX,
    required this.riseY,
    required this.size,
    required this.delay,
    required this.color,
  });
}
