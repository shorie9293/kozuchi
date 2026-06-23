import 'package:flutter/material.dart';
import 'package:kozuchi/features/effects/domain/effect_instance.dart';

/// 全画面発光エフェクト — SATORI MAX（開眼段階: 空）到達時に発動
///
/// 画面全体を柔らかく金色に包み込み、約3秒間かけて
/// 静かに立ち上がり、パルスし、消えていく。
///
/// 使用例（EffectManagerのeffectBuilder内）:
/// ```dart
/// 'full_glow' => SatoriGlowEffect(instance: instance),
/// ```
class SatoriGlowEffect extends StatefulWidget {
  final EffectInstance instance;
  const SatoriGlowEffect({super.key, required this.instance});

  @override
  State<SatoriGlowEffect> createState() => _SatoriGlowEffectState();
}

class _SatoriGlowEffectState extends State<SatoriGlowEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    final duration = widget.instance.definition.duration;
    _controller = AnimationController(
      duration: duration,
      vsync: this,
    );

    // 三段階のカーブ:
    //   0.0–0.15: 急速立ち上がり (0 → 1.0)
    //   0.15–0.65: ゆるやかなパルス (1.0 → 0.85 → 1.0)
    //   0.65–1.0: 静かな減衰 (1.0 → 0.0)
    _opacity = TweenSequence<double>([
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        weight: 15, // 15%: fade-in
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.0, end: 0.85),
        weight: 25, // 25%: gentle dip
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0.85, end: 1.0),
        weight: 25, // 25%: return to peak
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.0, end: 0.0),
        weight: 35, // 35%: fade-out
      ),
    ]).animate(_controller);

    _controller.forward();
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
        return Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: _opacity.value,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0.0, -0.3),
                    radius: 1.5,
                    colors: [
                      Color(0x40FFD700), // 中心: 金色 (alpha 25%)
                      Color(0x20FFE4B5), // 中間: モカシン (alpha 12%)
                      Color(0x00FFFFFF), // 外縁: 完全透明
                    ],
                    stops: [0.0, 0.6, 1.0],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
