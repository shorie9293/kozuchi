import 'dart:math';
import 'package:flutter/material.dart';

/// 縁起曼荼羅ウィジェット
///
/// 5つのノード（我→店→職人→家族→智慧）を黄金比の螺旋状に配置し、
/// ノード間を光の線（グラデーション＋アニメーションする光の粒子）で結ぶ曼荼羅。
/// 空段階の裏面モード時に表示される。
class EngiMandalaWidget extends StatefulWidget {
  /// 表示するかどうか（falseの場合は空のSizedBoxを返す）
  final bool isVisible;

  const EngiMandalaWidget({super.key, required this.isVisible});

  @override
  State<EngiMandalaWidget> createState() => _EngiMandalaWidgetState();
}

class _EngiMandalaWidgetState extends State<EngiMandalaWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  // 5つのノード定義（螺旋上の位置）
  static const List<_MandalaNode> _nodes = [
    _MandalaNode(label: '我', radiusFactor: 0.15, angleOffset: 0),
    _MandalaNode(label: '店', radiusFactor: 0.35, angleOffset: pi * 0.4),
    _MandalaNode(label: '職人', radiusFactor: 0.55, angleOffset: pi * 0.8),
    _MandalaNode(label: '家族', radiusFactor: 0.75, angleOffset: pi * 1.2),
    _MandalaNode(label: '智慧', radiusFactor: 0.95, angleOffset: pi * 1.6),
  ];

  // ノード間の接続（エッジ）
  static const List<List<int>> _edges = [
    [0, 1], // 我→店
    [1, 2], // 店→職人
    [2, 3], // 職人→家族
    [3, 4], // 家族→智慧
    [0, 2], // 我→職人（螺旋を跳ぶ）
    [1, 3], // 店→家族
    [2, 4], // 職人→智慧
    [0, 4], // 我→智慧（曼荼羅の環）
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();
    _animation = _controller;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) {
      return const SizedBox.shrink();
    }

    return KeyedSubtree(
      key: const Key('engi_mandala_widget'),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return SizedBox(
            width: double.infinity,
            height: 300,
            child: CustomPaint(
              key: const Key('engi_mandala_custom_paint'),
              painter: _MandalaPainter(
                animationValue: _animation.value,
                nodes: _nodes,
                edges: _edges,
              ),
              child: _buildNodeLabels(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNodeLabels() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final centerX = constraints.maxWidth / 2;
        final centerY = constraints.maxHeight / 2;
        final maxRadius = min(constraints.maxWidth, constraints.maxHeight) / 2 - 24;

        return Stack(
          children: _nodes.map((node) {
            final x = centerX + cos(node.angleOffset) * node.radiusFactor * maxRadius;
            final y = centerY + sin(node.angleOffset) * node.radiusFactor * maxRadius;
            return Positioned(
              left: x - 20,
              top: y - 20,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.7),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    node.label,
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
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

/// 曼荼羅のノード定義
class _MandalaNode {
  final String label;
  final double radiusFactor;
  final double angleOffset;

  const _MandalaNode({
    required this.label,
    required this.radiusFactor,
    required this.angleOffset,
  });
}

/// 曼荼羅を描画するCustomPainter
class _MandalaPainter extends CustomPainter {
  final double animationValue;
  final List<_MandalaNode> nodes;
  final List<List<int>> edges;

  _MandalaPainter({
    required this.animationValue,
    required this.nodes,
    required this.edges,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final maxRadius = min(size.width, size.height) / 2 - 24;

    // ノード位置を計算
    final positions = nodes.map((node) {
      final x = centerX + cos(node.angleOffset) * node.radiusFactor * maxRadius;
      final y = centerY + sin(node.angleOffset) * node.radiusFactor * maxRadius;
      return Offset(x, y);
    }).toList();

    // エッジ（光の線）を描画
    for (final edge in edges) {
      final start = positions[edge[0]];
      final end = positions[edge[1]];
      _drawLightLine(canvas, start, end);
    }

    // 光の粒子（アニメーション）
    for (final edge in edges) {
      final start = positions[edge[0]];
      final end = positions[edge[1]];
      _drawLightParticle(canvas, start, end, animationValue);
    }
  }

  void _drawLightLine(Canvas canvas, Offset start, Offset end) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.amber.withValues(alpha: 0.15),
          Colors.orange.withValues(alpha: 0.25),
          Colors.amber.withValues(alpha: 0.15),
        ],
      ).createShader(Rect.fromPoints(start, end))
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(start, end, paint);
  }

  void _drawLightParticle(Canvas canvas, Offset start, Offset end, double progress) {
    // progressに応じて粒子が線上を移動
    final t = (progress * 7) % 1.0; // 複数の粒子が異なる位置に
    final x = start.dx + (end.dx - start.dx) * t;
    final y = start.dy + (end.dy - start.dy) * t;

    final particlePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    canvas.drawCircle(Offset(x, y), 3, particlePaint);

    // 2つ目の粒子（位相をずらして）
    final t2 = (progress * 7 + 0.3) % 1.0;
    final x2 = start.dx + (end.dx - start.dx) * t2;
    final y2 = start.dy + (end.dy - start.dy) * t2;

    final particlePaint2 = Paint()
      ..color = Colors.amber.withValues(alpha: 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    canvas.drawCircle(Offset(x2, y2), 2, particlePaint2);
  }

  @override
  bool shouldRepaint(covariant _MandalaPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
