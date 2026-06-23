import 'package:flutter/material.dart';
import 'package:kozuchi/features/effects/domain/effect_instance.dart';

/// プレースホルダーエフェクト
///
/// 指定位置に現れるパルスする円形のエフェクト。
/// サンプル実装として、かつテスト用の参照エフェクトとして機能する。
///
/// 使用例（EffectManagerのeffectBuilder内）:
/// ```dart
/// 'placeholder' => PlaceholderEffect(instance: instance),
/// ```
class PlaceholderEffect extends StatefulWidget {
  final EffectInstance instance;
  const PlaceholderEffect({super.key, required this.instance});

  @override
  State<PlaceholderEffect> createState() => _PlaceholderEffectState();
}

class _PlaceholderEffectState extends State<PlaceholderEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.instance.definition.duration,
      vsync: this,
    );
    _scale = Tween<double>(begin: 0.0, end: 1.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.3, 1.0)),
    );
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
        return Positioned(
          left: widget.instance.position.dx - 24 * _scale.value,
          top: widget.instance.position.dy - 24 * _scale.value,
          child: IgnorePointer(
            child: Opacity(
              opacity: _opacity.value,
              child: Container(
                width: 48 * _scale.value,
                height: 48 * _scale.value,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF7C4DFF),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
