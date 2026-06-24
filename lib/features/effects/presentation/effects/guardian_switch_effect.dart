import 'dart:math';

import 'package:flutter/material.dart';
import 'package:kozuchi/domain/models/advisor.dart';
import 'package:kozuchi/features/effects/domain/effect_instance.dart';
import 'package:kozuchi/features/effects/domain/guardian_farewell_messages.dart';

/// 守護神切替演出エフェクト
///
/// 守護神の切り替え成功時に表示する全画面演出。
/// 暗幕フェードイン → 旧守護神の別れの言葉 → パーティクル散開 →
/// 新守護神の契約メッセージ → フェードアウト。
///
/// タップでスキップ可能。4秒で自動終了。
///
/// EffectInstanceの追加データ:
/// - parameters['oldAdvisor']: 旧守護神（Advisor enumのindex）
/// - parameters['newAdvisor']: 新守護神（Advisor enumのindex）
class GuardianSwitchEffect extends StatefulWidget {
  final EffectInstance instance;
  const GuardianSwitchEffect({super.key, required this.instance});

  @override
  State<GuardianSwitchEffect> createState() => _GuardianSwitchEffectState();
}

class _GuardianSwitchEffectState extends State<GuardianSwitchEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  late final Animation<double> _fadeOut;
  late final Animation<double> _messageProgress;
  late final List<_SwitchParticle> _particles;
  final _random = Random();

  bool _isSkipped = false;

  Advisor get _oldAdvisor => Advisor.values[
        (widget.instance.definition.parameters?['oldAdvisor'] as int?) ?? 0
      ];

  Advisor get _newAdvisor => Advisor.values[
        (widget.instance.definition.parameters?['newAdvisor'] as int?) ?? 0
      ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    );

    // フェーズ分け:
    // 0.0-0.2: 暗幕フェードイン
    // 0.15-0.45: 旧守護神の別れメッセージ
    // 0.35-0.65: パーティクル散開（新旧の狭間）
    // 0.55-0.85: 新守護神の契約メッセージ
    // 0.75-1.0: フェードアウト

    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.2, curve: Curves.easeIn),
      ),
    );
    _fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.75, 1.0, curve: Curves.easeOut),
      ),
    );
    _messageProgress = _controller;

    _particles = _generateParticles(20);

    _controller.forward();
  }

  List<_SwitchParticle> _generateParticles(int count) {
    final particles = <_SwitchParticle>[];
    final symbols = ['✨', '🌟', '💫', '⚡', '💠', '🔮'];
    for (var i = 0; i < count; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final distance = 30.0 + _random.nextDouble() * 150.0;
      final rotation = (_random.nextDouble() - 0.5) * 4 * pi;
      final size = 12.0 + _random.nextDouble() * 14.0;
      final symbol = symbols[_random.nextInt(symbols.length)];
      // パーティクル発動の遅延（0.3-0.6の間に散る）
      final delay = 0.3 + _random.nextDouble() * 0.3;
      // カラー: 金色系ランダム
      final color = Color.fromARGB(
        255,
        200 + _random.nextInt(55),
        150 + _random.nextInt(80),
        20 + _random.nextInt(40),
      );

      particles.add(_SwitchParticle(
        angle: angle,
        distance: distance,
        rotation: rotation,
        size: size,
        symbol: symbol,
        delay: delay,
        color: color,
      ));
    }
    return particles;
  }

  void _skip() {
    if (!_isSkipped) {
      _isSkipped = true;
      _controller.stop();
      // 即座に消滅させるためEffectManagerのremoveを待つ
      // 実際の消去はduration経過によるTimer発火だが、
      // 即座に非表示にする
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isSkipped) return const SizedBox.shrink();

    final screenSize = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        final size = MediaQuery.of(context).size;

        // フェード計算
        final overlayOpacity = (_fadeIn.value * _fadeOut.value).clamp(0.0, 1.0);
        // 旧メッセージの表示（0.15-0.5）
        final oldMessageOpacity = progress < 0.15
            ? 0.0
            : progress < 0.25
                ? ((progress - 0.15) / 0.1).clamp(0.0, 1.0)
                : progress < 0.4
                    ? 1.0
                    : progress < 0.5
                        ? (1.0 - (progress - 0.4) / 0.1).clamp(0.0, 1.0)
                        : 0.0;
        // 新メッセージの表示（0.5-0.85）
        final newMessageOpacity = progress < 0.5
            ? 0.0
            : progress < 0.6
                ? ((progress - 0.5) / 0.1).clamp(0.0, 1.0)
                : progress < 0.75
                    ? 1.0
                    : progress < 0.85
                        ? (1.0 - (progress - 0.75) / 0.1).clamp(0.0, 1.0)
                        : 0.0;

        return IgnorePointer(
          ignoring: !_isSkipped,
          child: GestureDetector(
            onTap: _skip,
            behavior: HitTestBehavior.opaque,
            child: Stack(
              children: [
                // 暗幕背景
                Positioned.fill(
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: overlayOpacity * 0.85,
                      child: Container(color: Colors.black),
                    ),
                  ),
                ),
                // パーティクル
                ..._particles.map((p) {
                  if (progress < p.delay) return const SizedBox.shrink();
                  final localProgress = (progress - p.delay) / (0.7 - p.delay);
                  final clampedProgress = localProgress.clamp(0.0, 1.0);
                  final dx = cos(p.angle) * p.distance * clampedProgress;
                  final dy = sin(p.angle) * p.distance * clampedProgress;
                  final particleOpacity =
                      (1.0 - clampedProgress).clamp(0.0, 1.0);

                  return Positioned(
                    left: size.width / 2 + dx - p.size / 2,
                    top: size.height * 0.4 + dy - p.size / 2,
                    child: IgnorePointer(
                      child: Transform.rotate(
                        angle: p.rotation * clampedProgress,
                        child: Opacity(
                          opacity: particleOpacity * overlayOpacity,
                          child: Text(
                            p.symbol,
                            style: TextStyle(
                              fontSize: p.size,
                              color: p.color,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                // 中央のメッセージエリア
                Positioned(
                  left: 0,
                  right: 0,
                  top: size.height * 0.3,
                  child: IgnorePointer(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 旧守護神の別れの言葉
                        Opacity(
                          opacity: oldMessageOpacity * overlayOpacity,
                          child: Column(
                            children: [
                              Text(
                                _oldAdvisor.emoji,
                                style: const TextStyle(fontSize: 48),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${_oldAdvisor.label}が去っていく…',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                margin: const EdgeInsets.symmetric(horizontal: 32),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  GuardianFarewellMessages.farewell(_oldAdvisor),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                        // 新守護神の契約メッセージ
                        Opacity(
                          opacity: newMessageOpacity * overlayOpacity,
                          child: Column(
                            children: [
                              Text(
                                _newAdvisor.emoji,
                                style: const TextStyle(fontSize: 48),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                GuardianFarewellMessages.contractGreeting(_newAdvisor),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.withValues(alpha: 0.9),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // スキップヒント（下部）
                if (progress < 0.8)
                  Positioned(
                    bottom: 60,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Center(
                        child: Opacity(
                          opacity: overlayOpacity * 0.6,
                          child: Text(
                            'タップでスキップ',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SwitchParticle {
  final double angle;
  final double distance;
  final double rotation;
  final double size;
  final String symbol;
  final double delay;
  final Color color;

  const _SwitchParticle({
    required this.angle,
    required this.distance,
    required this.rotation,
    required this.size,
    required this.symbol,
    required this.delay,
    required this.color,
  });
}
