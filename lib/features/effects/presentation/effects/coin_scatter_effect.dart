import 'dart:math';

import 'package:flutter/material.dart';
import 'package:kozuchi/features/effects/domain/effect_instance.dart';

/// コイン散布エフェクト
///
/// 支出実行時に、指定位置から複数の金貨が四方に飛び散る演出を行う。
/// 各コインはランダムな角度・距離・回転で飛翔し、徐々にフェードアウトする。
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
      widget.instance.definition.particleCount ?? 12,
    );
    _controller.forward();
  }

  List<_CoinParticle> _generateCoins(int count) {
    final coins = <_CoinParticle>[];
    for (var i = 0; i < count; i++) {
      // ランダムな角度（全方向）
      final angle = _random.nextDouble() * 2 * pi;
      // ランダムな飛距離（40〜120px）
      final distance = 40.0 + _random.nextDouble() * 80.0;
      // ランダムな回転（-2π〜2π）
      final rotation = (_random.nextDouble() - 0.5) * 4 * pi;
      // ランダムなサイズ（16〜24px）
      final size = 16.0 + _random.nextDouble() * 8.0;
      // ランダムなコイン絵文字（3種）
      final emojis = ['💰', '🪙', '💸'];
      final emoji = emojis[_random.nextInt(emojis.length)];

      coins.add(_CoinParticle(
        angle: angle,
        distance: distance,
        rotation: rotation,
        size: size,
        emoji: emoji,
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
          children: _coins.map((coin) {
            final dx = cos(coin.angle) * coin.distance * _progress.value;
            final dy = sin(coin.angle) * coin.distance * _progress.value;
            // フェード：前半0.7まで不透明、後半でフェードアウト
            final opacity = _progress.value < 0.7
                ? 1.0
                : 1.0 - ((_progress.value - 0.7) / 0.3);

            return Positioned(
              left: widget.instance.position.dx + dx - coin.size / 2,
              top: widget.instance.position.dy + dy - coin.size / 2,
              child: IgnorePointer(
                child: Transform.rotate(
                  angle: coin.rotation * _progress.value,
                  child: Opacity(
                    opacity: opacity.clamp(0.0, 1.0),
                    child: Text(
                      coin.emoji,
                      style: TextStyle(fontSize: coin.size),
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

/// 1粒のコインパーティクル
class _CoinParticle {
  final double angle;
  final double distance;
  final double rotation;
  final double size;
  final String emoji;

  const _CoinParticle({
    required this.angle,
    required this.distance,
    required this.rotation,
    required this.size,
    required this.emoji,
  });
}
