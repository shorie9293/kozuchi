import 'dart:math';

import 'package:flutter/material.dart';
import 'package:kozuchi/features/effects/domain/effect_instance.dart';

/// 桜吹雪エフェクト
///
/// 入金（deposit）時に表示される、ピンク色の花びらが舞い上がる祝福エフェクト。
/// 指定位置を中心に、複数の花びらが渦を描きながら上昇し、フェードアウトする。
///
/// [particleCount] 枚の花びらを生成し、それぞれがランダムな軌道で
/// 2〜3秒かけて舞い上がる。
///
/// 使用例（EffectManagerのeffectBuilder内）:
/// ```dart
/// 'cherry_snow' => CherryBlizzardEffect(instance: instance),
/// ```
class CherryBlizzardEffect extends StatefulWidget {
  final EffectInstance instance;
  const CherryBlizzardEffect({super.key, required this.instance});

  @override
  State<CherryBlizzardEffect> createState() => _CherryBlizzardEffectState();
}

/// 1枚の花びらの状態
class _Petal {
  final double startX;
  final double startY;
  final double size;
  final double rotation;
  final double spiralRadius;
  final double riseSpeed;
  final Color color;
  final double delay;

  const _Petal({
    required this.startX,
    required this.startY,
    required this.size,
    required this.rotation,
    required this.spiralRadius,
    required this.riseSpeed,
    required this.color,
    required this.delay,
  });
}

class _CherryBlizzardEffectState extends State<CherryBlizzardEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Petal> _petals;

  static final _random = Random();

  static final List<Color> _petalColors = const [
    Color(0xFFFFB7C5), // 桜ピンク
    Color(0xFFFFC0CB), // ピンク
    Color(0xFFFFD1DC), // 淡いピンク
    Color(0xFFFF91A4), // 濃い桜
    Color(0xFFFFE4E1), // ミスティローズ
    Color(0xFFFF69B4), // ホットピンク
  ];

  @override
  void initState() {
    super.initState();
    final particleCount =
        widget.instance.definition.particleCount ?? 30;
    final duration = widget.instance.definition.duration;

    _controller = AnimationController(
      duration: duration,
      vsync: this,
    );

    _petals = List.generate(particleCount, (_) => _generatePetal());
    _controller.forward();
  }

  _Petal _generatePetal() {
    return _Petal(
      startX: (_random.nextDouble() - 0.5) * 120,
      startY: (_random.nextDouble() - 0.5) * 40,
      size: 6.0 + _random.nextDouble() * 10.0,
      rotation: _random.nextDouble() * 2 * pi,
      spiralRadius: 20.0 + _random.nextDouble() * 60.0,
      riseSpeed: 0.6 + _random.nextDouble() * 0.4,
      color: _petalColors[_random.nextInt(_petalColors.length)],
      delay: _random.nextDouble() * 0.3,
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
        return Stack(
          children: [
            for (final petal in _petals) _buildPetal(petal),
          ],
        );
      },
    );
  }

  Widget _buildPetal(_Petal petal) {
    final t = _controller.value;
    // 遅延を考慮した進捗（0→1）
    final delayedT =
        ((t - petal.delay) / (1.0 - petal.delay)).clamp(0.0, 1.0);

    // 上昇アニメーション
    final riseY = -delayedT * 200.0 * petal.riseSpeed;

    // 渦巻き運動
    final angle = petal.rotation + delayedT * 4 * pi;
    final spiralX = sin(angle) * petal.spiralRadius * delayedT;
    final spiralY = cos(angle) * petal.spiralRadius * delayedT * 0.3;

    // フェードアウト（後半30%で加速）
    final opacity = delayedT < 0.7
        ? 1.0
        : 1.0 - ((delayedT - 0.7) / 0.3).clamp(0.0, 1.0);

    // スケール（徐々に小さく）
    final scale = 1.0 - delayedT * 0.4;

    // 回転
    final rotation = angle * 0.5;

    final baseX = widget.instance.position.dx;
    final baseY = widget.instance.position.dy;

    return Positioned(
      left: 0,
      top: 0,
      child: IgnorePointer(
        child: Transform.translate(
          offset: Offset(
            baseX + petal.startX + spiralX,
            baseY + petal.startY + riseY - spiralY,
          ),
          child: Transform.rotate(
            angle: rotation,
            child: Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: petal.size,
                  height: petal.size * 1.3,
                  decoration: BoxDecoration(
                    color: petal.color,
                    borderRadius: BorderRadius.circular(petal.size * 0.6),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
