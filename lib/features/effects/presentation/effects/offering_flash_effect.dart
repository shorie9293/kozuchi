import 'package:flutter/material.dart';
import 'package:kozuchi/features/effects/domain/effect_instance.dart';

/// 支出記録時の画面フラッシュエフェクト
///
/// 支出実行直後に全画面が金色に一瞬発光し、徐々にフェードアウトする。
/// 爽快感を高めるための演出。
///
/// アニメーション仕様:
/// - 0〜50ms: 最盛期（透明度 0→1）
/// - 50ms〜400ms: フェードアウト（透明度 1→0）
///
/// 使用例（EffectManagerのeffectBuilder内）:
/// ```dart
/// 'offering_flash' => OfferingFlashEffect(instance: instance),
/// ```
class OfferingFlashEffect extends StatefulWidget {
  final EffectInstance instance;

  const OfferingFlashEffect({super.key, required this.instance});

  @override
  State<OfferingFlashEffect> createState() => _OfferingFlashEffectState();
}

class _OfferingFlashEffectState extends State<OfferingFlashEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    final totalDuration = widget.instance.definition.duration;

    _controller = AnimationController(
      duration: totalDuration,
      vsync: this,
    );

    // 2段階のオパシティカーブ
    //   0.0–0.125: flash in (50ms / 400ms = 12.5%)
    //   0.125–1.0: fade out (350ms / 400ms = 87.5%)
    _opacity = TweenSequence<double>([
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0.0, end: 0.6),
        weight: 12.5,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0.6, end: 0.0),
        weight: 87.5,
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
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Positioned.fill(
            child: Opacity(
              opacity: _opacity.value,
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.2,
                    colors: [
                      const Color(0xFFFFD700).withValues(alpha: 0.8),
                      const Color(0xFFFFA500).withValues(alpha: 0.4),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
