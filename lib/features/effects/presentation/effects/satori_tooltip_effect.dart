import 'package:flutter/material.dart';
import 'package:kozuchi/features/effects/domain/effect_instance.dart';
import 'package:kozuchi/features/satori/domain/satori_change_event.dart';
import 'package:kozuchi/features/satori/data/satori_event_dispatcher.dart';

/// SATORI変動理由を吹き出しで表示するツールチップエフェクト
///
/// [SatoriEventDispatcher.lastEvent] から最新のSATORI変動理由を取得し、
/// アニメーション付きの吹き出しとして表示する。
///
/// アニメーション仕様:
/// - 0〜200ms: fade-in（透明度 0→1）
/// - 200ms〜2700ms: hold（透明度 1.0 を維持）
/// - 2700ms〜3000ms: fade-out（透明度 1→0）
///
/// [EffectInstance.position] に追従して表示位置を決める。
class SatoriTooltipEffect extends StatefulWidget {
  final EffectInstance instance;

  const SatoriTooltipEffect({super.key, required this.instance});

  @override
  State<SatoriTooltipEffect> createState() => _SatoriTooltipEffectState();
}

class _SatoriTooltipEffectState extends State<SatoriTooltipEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  SatoriChangeEvent? get _event => SatoriEventDispatcher.instance.lastEvent;

  @override
  void initState() {
    super.initState();
    final totalDuration = widget.instance.definition.duration;

    _controller = AnimationController(
      duration: totalDuration,
      vsync: this,
    );

    // 3段階のオパシティカーブ
    //   0.0–0.067: fade-in (200ms / 3000ms ≈ 6.7%)
    //   0.067–0.90: hold (2500ms / 3000ms ≈ 83.3%)
    //   0.90–1.0: fade-out (300ms / 3000ms ≈ 10%)
    _opacity = TweenSequence<double>([
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        weight: 6.7,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.0, end: 1.0),
        weight: 83.3,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.0, end: 0.0),
        weight: 10.0,
      ),
    ]).animate(_controller);

    // わずかに上方向へ浮き上がるスライド
    _slide = TweenSequence<Offset>([
      TweenSequenceItem<Offset>(
        tween: Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ),
        weight: 6.7,
      ),
      TweenSequenceItem<Offset>(
        tween: Tween<Offset>(begin: Offset.zero, end: Offset.zero),
        weight: 83.3,
      ),
      TweenSequenceItem<Offset>(
        tween: Tween<Offset>(begin: Offset.zero, end: const Offset(0, -0.1)),
        weight: 10.0,
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
    final event = _event;
    if (event == null) return const SizedBox.shrink();

    final isIncrease = event.direction == SatoriDirection.increase;
    final colorScheme = Theme.of(context).colorScheme;

    // 増加時：緑系、減少時：赤系
    final bubbleColor = isIncrease
        ? Color.lerp(colorScheme.primaryContainer, Colors.green.shade100, 0.5)
            ?.withValues(alpha: 0.95) ??
            Colors.green.shade100.withValues(alpha: 0.95)
        : Color.lerp(colorScheme.errorContainer, Colors.red.shade100, 0.5)
            ?.withValues(alpha: 0.95) ??
            Colors.red.shade100.withValues(alpha: 0.95);

    final arrow = isIncrease ? '⬆️' : '⬇️';
    final deltaText = '${arrow} ${event.delta} EXP';

    return Positioned(
      top: widget.instance.position.dy,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _opacity.value,
            child: SlideTransition(
              position: _slide,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          event.reason,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isIncrease
                                ? colorScheme.onPrimaryContainer
                                : colorScheme.onErrorContainer,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          deltaText,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isIncrease
                                ? colorScheme.onPrimaryContainer
                                    .withValues(alpha: 0.7)
                                : colorScheme.onErrorContainer
                                    .withValues(alpha: 0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
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
