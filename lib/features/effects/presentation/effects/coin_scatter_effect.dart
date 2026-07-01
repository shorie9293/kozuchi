import 'dart:math';

import 'package:flutter/material.dart';
import 'package:kozuchi/features/effects/domain/effect_instance.dart';

/// コイン散布エフェクト
///
/// 支出実行時に、指定位置から複数の金貨が四方に飛び散る演出を行う。
/// 各コインはランダムな角度・距離・回転で飛翔し、徐々にフェードアウトする。
/// コインの背後に金色の光彩が広がり、コイン自体は拡大から縮小のアニメーションを行う。
/// 持続時間は [EffectInstance.definition.duration]（デフォルト2秒）。
///
/// 使用例（EffectManagerのeffectBuilder内）:
/// ```dart
/// 'coin_scatter' => CoinScatterEffect(instance: instance),
/// ```
class CoinScatterEffect extends StatefulWidget {
  final EffectInstance instance;
  const CoinScatterEffect({super.key, required this.instance});

  @override
  State<CoinScatterEffect> createState() => _CoinScatterEffectState();
}

class _CoinScatterEffectState extends State<CoinScatterEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;
  late final List<_CoinParticle> _coins;
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
    _coins = _generateCoins(
      widget.instance.definition.particleCount ?? 20,
    );
    _controller.forward();
  }

  List<_CoinParticle> _generateCoins(int count) {
    final coins = <_CoinParticle>[];
    for (var i = 0; i < count; i++) {
      // ランダムな角度（全方向）
      final angle = _random.nextDouble() * 2 * pi;
      // ランダムな飛距離（50〜150px）
      final distance = 50.0 + _random.nextDouble() * 100.0;
      // ランダムな回転（-2π〜2π）
      final rotation = (_random.nextDouble() - 0.5) * 4 * pi;
      // ランダムなサイズ（20〜32px、初期は大きめ）
      final size = 20.0 + _random.nextDouble() * 12.0;
      // ランダムなコイン絵文字（3種）
      final emojis = ['💰', '🪙', '💸'];
      final emoji = emojis[_random.nextInt(emojis.length)];
      // ランダムな遅延（0〜0.15秒相当のprogress）
      final delay = _random.nextDouble() * 0.15;

      coins.add(_CoinParticle(
        angle: angle,
        distance: distance,
        rotation: rotation,
        size: size,
        emoji: emoji,
        delay: delay,
      ));
    }
    return coins;
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
            // 金色の光彩（背景に広がる）
            ..._buildGlow(),
            // コイン
            ..._coins.map((coin) {
              final effectiveProgress =
                  ((_progress.value - coin.delay) / (1.0 - coin.delay))
                      .clamp(0.0, 1.0);
              final dx = cos(coin.angle) * coin.distance * effectiveProgress;
              final dy = sin(coin.angle) * coin.distance * effectiveProgress;
              // フェード：前半0.6まで不透明、後半でフェードアウト
              final opacity = effectiveProgress < 0.6
                  ? 1.0
                  : 1.0 - ((effectiveProgress - 0.6) / 0.4);
              // スケール：開始時1.5倍から徐々に縮小
              final scale = 1.5 - 0.5 * effectiveProgress;

              return Positioned(
                left: widget.instance.position.dx + dx - coin.size / 2,
                top: widget.instance.position.dy + dy - coin.size / 2,
                child: IgnorePointer(
                  child: Transform.rotate(
                    angle: coin.rotation * effectiveProgress,
                    child: Transform.scale(
                      scale: scale.clamp(0.8, 1.5),
                      child: Opacity(
                        opacity: opacity.clamp(0.0, 1.0),
                        child: Text(
                          coin.emoji,
                          style: TextStyle(fontSize: coin.size),
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

  /// コインの背後に広がる金色の光彩を生成する
  List<Widget> _buildGlow() {
    // 進行度に応じて光彩が広がり、消えていく
    final glowProgress = _progress.value;
    final glowOpacity = glowProgress < 0.3
        ? glowProgress / 0.3
        : glowProgress < 0.7
            ? 1.0
            : 1.0 - ((glowProgress - 0.7) / 0.3);
    final glowRadius = 20.0 + glowProgress * 80.0;

    return [
      Positioned(
        left: widget.instance.position.dx - glowRadius * 2,
        top: widget.instance.position.dy - glowRadius * 2,
        child: IgnorePointer(
          child: Opacity(
            opacity: glowOpacity.clamp(0.0, 0.4),
            child: Container(
              width: glowRadius * 4,
              height: glowRadius * 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.0,
                  colors: [
                    const Color(0xFFFFD700).withValues(alpha: 0.6),
                    const Color(0xFFFFA500).withValues(alpha: 0.2),
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

/// 1粒のコインパーティクル
class _CoinParticle {
  final double angle;
  final double distance;
  final double rotation;
  final double size;
  final String emoji;
  final double delay;

  const _CoinParticle({
    required this.angle,
    required this.distance,
    required this.rotation,
    required this.size,
    required this.emoji,
    required this.delay,
  });
}
