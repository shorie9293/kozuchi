import 'dart:math';

import 'package:flutter/material.dart';
import 'package:kozuchi/features/effects/domain/effect_instance.dart';

/// 光の柱エフェクト — 喜捨（寄付）成功時に発動
///
/// 指定位置から上空へ伸びる金色の光の柱と、周囲に舞う煌めき（スパークル）を表示する。
/// [EffectInstance.definition.duration]（デフォルト2.5秒）の間、
/// 光柱が立ち昇り、煌めき、消えていく。
///
/// 使用例（EffectManagerのeffectBuilder内）:
/// ```dart
/// 'light_pillar' => PillarOfLightEffect(instance: instance),
/// ```
class PillarOfLightEffect extends StatefulWidget {
  final EffectInstance instance;
  const PillarOfLightEffect({super.key, required this.instance});

  @override
  State<PillarOfLightEffect> createState() => _PillarOfLightEffectState();
}

/// 1粒の煌めき（スパークル）の状態
class _Sparkle {
  final double offsetX;
  final double offsetY;
  final double size;
  final double delay;
  final double twinkleSpeed;

  const _Sparkle({
    required this.offsetX,
    required this.offsetY,
    required this.size,
    required this.delay,
    required this.twinkleSpeed,
  });
}

class _PillarOfLightEffectState extends State<PillarOfLightEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Sparkle> _sparkles;

  static final _random = Random();

  @override
  void initState() {
    super.initState();
    final duration = widget.instance.definition.duration;

    _controller = AnimationController(
      duration: duration,
      vsync: this,
    );

    _sparkles = List.generate(18, (_) => _generateSparkle());
    _controller.forward();
  }

  _Sparkle _generateSparkle() {
    // 光柱の周囲（横幅±60px、高さ0〜-240pxの範囲）にランダム配置
    return _Sparkle(
      offsetX: (_random.nextDouble() - 0.5) * 120,
      offsetY: -_random.nextDouble() * 240,
      size: 2.0 + _random.nextDouble() * 5.0,
      delay: _random.nextDouble() * 0.4,
      twinkleSpeed: 2.0 + _random.nextDouble() * 3.0,
    );
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
        final t = _controller.value;

        // 光柱の高さアニメーション: 0-15%で急速に伸び、15-70%で維持、70-100%でフェード
        final beamHeight = _beamHeightTween(t);
        // 光柱の不透明度
        final beamOpacity = _beamOpacityTween(t);
        // 光柱の幅（下部は細く、上部はやや広がる）
        final beamTopWidth = 4.0 + t * 24.0;

        final baseX = widget.instance.position.dx;
        final baseY = widget.instance.position.dy;

        return Stack(
          children: [
            // 光の柱
            Positioned(
              left: baseX - beamTopWidth / 2,
              top: baseY - beamHeight,
              child: IgnorePointer(
                child: Opacity(
                  opacity: beamOpacity,
                  child: Container(
                    width: beamTopWidth,
                    height: beamHeight,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Color(0xFFFFD700), // 金色（底部：不透明）
                          Color(0xAAFFD700), // 金色（中間：半透明）
                          Color(0x44FFE4B5), // モカシン（上部：薄い）
                          Color(0x00FFFFFF), // 完全透明（頂点）
                        ],
                        stops: [0.0, 0.3, 0.7, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x80FFD700),
                          blurRadius: 12,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // 煌めき（スパークル）
            for (final sparkle in _sparkles)
              _buildSparkle(sparkle, t, baseX, baseY),
          ],
        );
      },
    );
  }

  Widget _buildSparkle(
      _Sparkle sparkle, double t, double baseX, double baseY) {
    // 遅延を考慮した進捗
    final delayedT =
        ((t - sparkle.delay) / (1.0 - sparkle.delay)).clamp(0.0, 1.0);

    if (delayedT <= 0.0) return const SizedBox.shrink();

    // 煌めき: sin波で明滅
    final twinkle =
        (sin(delayedT * sparkle.twinkleSpeed * pi) + 1.0) / 2.0;

    // フェードアウト（後半30%で）
    final fadeOut = delayedT < 0.7 ? 1.0 : 1.0 - ((delayedT - 0.7) / 0.3);
    final opacity = (twinkle * 0.8 + 0.2) * fadeOut.clamp(0.0, 1.0);

    // スパークルは徐々に上昇
    final riseY = sparkle.offsetY - delayedT * 60.0;

    // スパークルの色：金色〜白の間
    final sparkleColor = Color.lerp(
      const Color(0xFFFFD700),
      const Color(0xFFFFFFFF),
      twinkle,
    )!;

    return Positioned(
      left: baseX + sparkle.offsetX - sparkle.size / 2,
      top: baseY + riseY - sparkle.size / 2,
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: Container(
            width: sparkle.size,
            height: sparkle.size,
            decoration: BoxDecoration(
              color: sparkleColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: sparkleColor.withValues(alpha: 0.6),
                  blurRadius: sparkle.size * 1.5,
                  spreadRadius: sparkle.size * 0.5,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 光柱の高さトゥイーン
  double _beamHeightTween(double t) {
    if (t < 0.15) {
      // 0-15%: 急速に伸びる (0 → 200px)
      return (t / 0.15) * 200.0;
    } else if (t < 0.7) {
      // 15-70%: 維持（わずかに脈動）
      final pulse = sin((t - 0.15) / 0.55 * 3 * pi) * 15.0;
      return 200.0 + pulse;
    } else {
      // 70-100%: 徐々に縮む
      final shrink = (t - 0.7) / 0.3;
      return 200.0 * (1.0 - shrink);
    }
  }

  /// 光柱の不透明度トゥイーン
  double _beamOpacityTween(double t) {
    if (t < 0.1) {
      return t / 0.1; // fade-in
    } else if (t < 0.7) {
      return 1.0; // maintain
    } else {
      return 1.0 - (t - 0.7) / 0.3; // fade-out
    }
  }
}
