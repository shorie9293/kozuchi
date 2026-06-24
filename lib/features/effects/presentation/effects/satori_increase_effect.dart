import 'dart:math';

import 'package:flutter/material.dart';
import 'package:kozuchi/features/effects/domain/effect_instance.dart';

/// SATORI増加時の光の粒子エフェクト
///
/// SATORI値が増加した際に、指定位置から光の粒子が上昇する演出を行う。
/// 各粒子はランダムな水平ドリフトと上昇速度で飛翔し、
/// 徐々にフェードアウトする。
///
/// 持続時間は [EffectInstance.definition.duration]（デフォルト1.5秒）。
/// 粒子数は [EffectInstance.definition.particleCount]（デフォルト8）。
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
      widget.instance.definition.particleCount ?? 8,
    );
    _controller.forward();
  }

  List<_LightParticle> _generateParticles(int count) {
    final particles = <_LightParticle>[];
    for (var i = 0; i < count; i++) {
      // ランダムな水平ドリフト (-30〜30px)
      final driftX = (_random.nextDouble() - 0.5) * 60.0;
      // ランダムな上昇距離 (40〜120px)
      final riseY = 40.0 + _random.nextDouble() * 80.0;
      // ランダムなサイズ (3〜8px)
      final size = 3.0 + _random.nextDouble() * 5.0;
      // ランダムな開始遅延 (0〜0.3秒相当のprogress)
      final delay = _random.nextDouble() * 0.2;

      particles.add(_LightParticle(
        driftX: driftX,
        riseY: riseY,
        size: size,
        delay: delay,
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
          children: _particles.map((particle) {
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

            return Positioned(
              left: widget.instance.position.dx + dx - particle.size / 2,
              top: widget.instance.position.dy + dy - particle.size / 2,
              child: IgnorePointer(
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Container(
                    width: particle.size,
                    height: particle.size,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: Alignment(0.0, 0.0),
                        radius: 1.0,
                        colors: [
                          Color(0xFFFFF8DC), // 中心: コーンスィルク（明るい白金色）
                          Color(0x80FFD700), // 中間: 半透明の金色
                          Color(0x00FFD700), // 外縁: 完全透明
                        ],
                        stops: [0.0, 0.3, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
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

  const _LightParticle({
    required this.driftX,
    required this.riseY,
    required this.size,
    required this.delay,
  });
}
