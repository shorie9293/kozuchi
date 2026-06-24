import 'package:flutter/material.dart';
import 'package:kozuchi/features/effects/domain/effect_instance.dart';

/// 闇の帳（ダークカーテン）エフェクト — SATORI減少時に発動
///
/// SATORI値の減少（悟りの後退）を表現するため、
/// SATORI表示領域（EXPゲージ上部）を闇色のオーバーレイで覆う。
///
/// アニメーションは3段階（~1.2秒）：
///   0–25%（0–300ms）:  闇の帳が素早く降下
///   25–75%（300–900ms）: 帳が留まり、かすかに脈動
///   75–100%（900–1200ms）: 帳が引き上げられフェードアウト
///
/// 増加エフェクト（グロー/光柱/桜吹雪）とは別系統の視覚言語を用いる。
class DarkCurtainEffect extends StatefulWidget {
  final EffectInstance instance;
  const DarkCurtainEffect({super.key, required this.instance});

  @override
  State<DarkCurtainEffect> createState() => _DarkCurtainEffectState();
}

class _DarkCurtainEffectState extends State<DarkCurtainEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curtainY;
  late final Animation<double> _curtainOpacity;

  /// 帳が覆う高さ（EXPゲージの領域 ≈ 120px）
  static const double _coverHeight = 130.0;

  @override
  void initState() {
    super.initState();
    final duration = widget.instance.definition.duration;
    _controller = AnimationController(
      duration: duration,
      vsync: this,
    );

    // 降下: 0→25%で急速に下りる
    // 滞留: 25→75%で維持
    // 上昇: 75→100%で引き上げ
    _curtainY = TweenSequence<double>([
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: -_coverHeight, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 25,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0.0, end: 4.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 4.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0.0, end: -_coverHeight)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 25,
      ),
    ]).animate(_controller);

    // 不透明度: 降下時に立ち上がり、滞留し、上昇時にフェード
    _curtainOpacity = TweenSequence<double>([
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0.0, end: 0.85),
        weight: 20,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0.85, end: 0.9),
        weight: 5,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0.9, end: 0.85),
        weight: 50,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0.85, end: 0.0),
        weight: 25,
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
        final y = _curtainY.value;
        final opacity = _curtainOpacity.value;

        return Positioned(
          left: 0,
          right: 0,
          top: y,
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity,
              child: Container(
                height: _coverHeight + 40, // 下部にフェード域を追加
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xDD1A1A2E), // 墨色（濃い闇）
                      const Color(0x881A1A2E), // 中間
                      const Color(0x221A1A2E), // 薄い闇
                      const Color(0x00000000), // 完全透明
                    ],
                    stops: const [0.0, 0.5, 0.8, 1.0],
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
