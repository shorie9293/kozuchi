import 'dart:math';
import 'package:flutter/material.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';

/// 和紙／墨色の背景ペインター
///
/// ライトテーマ：和紙白(#F5F0E8)＋淡い金箔アクセント
/// ダークテーマ：墨色(#1A1A2E)＋夜桜金箔アクセント（密度・透明度を微調整）
///
/// 旧MoneyBackgroundの黄色ベース配色（#FFECB3 系）を見直し、
/// 創造主様「黄色ベースでむちゃくちゃ見づらい」の神託に応えて刷新。
class WashiBackgroundPainter extends CustomPainter {
  final double animationValue;
  final bool isDark;

  WashiBackgroundPainter({
    this.animationValue = 0.0,
    this.isDark = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(42);

    if (isDark) {
      _paintDark(canvas, size, random);
    } else {
      _paintLight(canvas, size, random);
    }
  }

  /// ライトテーマ：和紙白グラデーション＋金箔
  void _paintLight(Canvas canvas, Size size, Random random) {
    // 背景：和紙白グラデーション
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [
          Color(0xFFF5F0E8), // 和紙白
          Color(0xFFF0EBE3), // 淡い生成り
          Color(0xFFF5F0E8), // 和紙白
          Color(0xFFEDE8E0), // ほんのりグレージュ
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 淡い金箔の散りばめ（密度6枚・透明度4〜10%に抑制）
    _drawGoldFoil(canvas, size, random,
        foilColor: const Color.fromRGBO(212, 160, 56, 1.0),
        foilCount: 6,
        foilOpacityMin: 0.04,
        foilOpacityMax: 0.10);

    // 淡いキラキラ
    _drawSubtleSparkle(canvas, size, random,
        sparkleColor: const Color.fromRGBO(212, 160, 56, 1.0),
        sparkleCount: 12,
        sparkleOpacityMin: 0.01,
        sparkleOpacityMax: 0.04);
  }

  /// ダークテーマ：墨色グラデーション＋夜桜金箔
  void _paintDark(Canvas canvas, Size size, Random random) {
    // 背景：墨色グラデーション
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [
          TakamagaharaColors.sumiDark,   // #1A1A2E 墨色
          Color(0xFF1E1E35),             // わずかに明るい墨
          TakamagaharaColors.sumiDark,   // 墨色
          Color(0xFF151528),             // わずかに暗い墨
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 夜桜金箔の散りばめ（密度10枚・透明度5〜12%にやや増量）
    _drawGoldFoil(canvas, size, random,
        foilColor: TakamagaharaColors.goldLeaf,
        foilCount: 10,
        foilOpacityMin: 0.05,
        foilOpacityMax: 0.12);

    // 星のようなキラキラ（より明るく、密度も増量）
    _drawSubtleSparkle(canvas, size, random,
        sparkleColor: TakamagaharaColors.goldLight,
        sparkleCount: 18,
        sparkleOpacityMin: 0.02,
        sparkleOpacityMax: 0.07);
  }

  void _drawGoldFoil(
    Canvas canvas,
    Size size,
    Random random, {
    required Color foilColor,
    required int foilCount,
    required double foilOpacityMin,
    required double foilOpacityMax,
  }) {
    for (int i = 0; i < foilCount; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final foilWidth = 30.0 + random.nextDouble() * 50.0;
      final foilHeight = foilWidth * 0.55;
      final opacity =
          foilOpacityMin + random.nextDouble() * (foilOpacityMax - foilOpacityMin);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(random.nextDouble() * 0.4 - 0.2);

      final foilPaint = Paint()
        ..color = foilColor.withValues(alpha: opacity);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: foilWidth,
            height: foilHeight,
          ),
          const Radius.circular(3),
        ),
        foilPaint,
      );
      canvas.restore();
    }
  }

  void _drawSubtleSparkle(
    Canvas canvas,
    Size size,
    Random random, {
    required Color sparkleColor,
    required int sparkleCount,
    required double sparkleOpacityMin,
    required double sparkleOpacityMax,
  }) {
    for (int i = 0; i < sparkleCount; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final sparkleSize = 2.0 + random.nextDouble() * 4.0;
      final opacity =
          (sparkleOpacityMin +
                  random.nextDouble() *
                      (sparkleOpacityMax - sparkleOpacityMin)) *
              (0.5 + 0.5 * sin(animationValue * 2 * pi + i));

      final sparklePaint = Paint()
        ..color = sparkleColor.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), sparkleSize, sparklePaint);
    }
  }

  @override
  bool shouldRepaint(WashiBackgroundPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.isDark != isDark;
  }
}

/// アニメーション付きの和紙／墨色背景ウィジェット
///
/// テーマのbrightnessに応じてライト／ダークの背景を自動切替。
class WashiBackground extends StatefulWidget {
  final Widget child;

  const WashiBackground({super.key, required this.child});

  @override
  State<WashiBackground> createState() => _WashiBackgroundState();
}

class _WashiBackgroundState extends State<WashiBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 12),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: WashiBackgroundPainter(
            animationValue: _controller.value,
            isDark: isDark,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
