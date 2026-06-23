import 'package:flutter/material.dart';
import 'dart:math';
import 'package:takamagahara_ui/takamagahara_ui.dart';

/// お金を楽しむコンセプトの背景ペインター
///
/// ライトテーマ：クリーム系グラデーション＋金貨・札・キラキラ
/// ダークテーマ：墨色系グラデーション＋金貨（薄金）・札・星光
class MoneyBackgroundPainter extends CustomPainter {
  final double animationValue;
  final bool isDark;

  MoneyBackgroundPainter({
    this.animationValue = 0.0,
    this.isDark = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(42); // 固定シードで再現性確保

    if (isDark) {
      _paintDark(canvas, size, random);
    } else {
      _paintLight(canvas, size, random);
    }
  }

  /// ライトテーマの背景
  void _paintLight(Canvas canvas, Size size, Random random) {
    // 背景グラデーション（温かみのあるゴールド系）
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [
          Color(0xFFFFF8E1), // 薄いクリーム
          Color(0xFFFFECB3), // 薄いゴールド
          Color(0xFFFFE0B2), // 薄いオレンジ
          Color(0xFFFFF3E0), // 薄いピーチ
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    _drawCoins(canvas, size, random,
        coinBase: const Color.fromRGBO(255, 215, 0, 1.0),
        coinMid: const Color.fromRGBO(255, 160, 0, 1.0),
        coinEdge: const Color.fromRGBO(255, 143, 0, 1.0));
    _drawBills(canvas, size, random,
        billColor: const Color.fromRGBO(129, 199, 132, 1.0),
        billBorder: const Color.fromRGBO(56, 142, 60, 1.0),
        billText: const Color.fromRGBO(27, 94, 32, 1.0));
    _drawSparkles(canvas, size, random,
        sparkleColor: const Color.fromRGBO(255, 215, 0, 1.0));
  }

  /// ダークテーマの背景 — 墨色基調 × 金貨・星光
  void _paintDark(Canvas canvas, Size size, Random random) {
    // 背景グラデーション（墨色系）
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [
          TakamagaharaColors.sumiDark,   // #1A1A2E
          Color(0xFF222238),             // わずかに明るい
          TakamagaharaColors.sumiDark,
          Color(0xFF161628),             // わずかに暗い
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 金貨（薄金系で密度・透明度を抑制）
    _drawCoins(canvas, size, random,
        coinBase: TakamagaharaColors.goldLeaf,
        coinMid: TakamagaharaColors.gold,
        coinEdge: TakamagaharaColors.goldDeep);

    // 札（暗めの緑）
    _drawBills(canvas, size, random,
        billColor: const Color.fromRGBO(46, 125, 50, 1.0),
        billBorder: const Color.fromRGBO(27, 94, 32, 1.0),
        billText: const Color.fromRGBO(165, 214, 167, 1.0));

    // 星光キラキラ（金）
    _drawSparkles(canvas, size, random,
        sparkleColor: TakamagaharaColors.goldLight);
  }

  void _drawCoins(
    Canvas canvas,
    Size size,
    Random random, {
    required Color coinBase,
    required Color coinMid,
    required Color coinEdge,
  }) {
    for (int i = 0; i < 12; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = 12.0 + random.nextDouble() * 15.0;
      final opacity = 0.10 + random.nextDouble() * 0.20;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(random.nextDouble() * pi * 0.3 - 0.15);

      final coinPaintWithOpacity = Paint()
        ..shader = RadialGradient(
          colors: [
            coinBase.withValues(alpha: opacity),
            coinMid.withValues(alpha: opacity),
            coinEdge.withValues(alpha: opacity * 0.8),
          ],
          stops: [0.0, 0.6, 1.0],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius));

      canvas.drawCircle(Offset.zero, radius, coinPaintWithOpacity);

      // 縁
      final borderWithOpacity = Paint()
        ..color = coinEdge.withValues(alpha: opacity * 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(Offset.zero, radius, borderWithOpacity);

      // 中央模様
      final innerPaint = Paint()
        ..color = coinMid.withValues(alpha: opacity * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawCircle(Offset.zero, radius * 0.6, innerPaint);

      // ¥マーク
      final textPainter = TextPainter(
        text: TextSpan(
          text: '¥',
          style: TextStyle(
            color: coinEdge.withValues(alpha: opacity * 0.7),
            fontSize: radius * 0.8,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );

      canvas.restore();
    }
  }

  void _drawBills(
    Canvas canvas,
    Size size,
    Random random, {
    required Color billColor,
    required Color billBorder,
    required Color billText,
  }) {
    for (int i = 0; i < 3; i++) {
      final x = random.nextDouble() * size.width * 0.8 + size.width * 0.1;
      final y = random.nextDouble() * size.height * 0.8 + size.height * 0.1;
      final opacity = 0.06 + random.nextDouble() * 0.10;
      final angle = random.nextDouble() * 0.4 - 0.2;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);

      final billWidth = 80.0 + random.nextDouble() * 40.0;
      final billHeight = billWidth * 0.5;

      final billPaint = Paint()
        ..color = billColor.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;
      final billRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset.zero, width: billWidth, height: billHeight),
        const Radius.circular(4),
      );
      canvas.drawRRect(billRect, billPaint);

      final billBorderPaint = Paint()
        ..color = billBorder.withValues(alpha: opacity * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawRRect(billRect, billBorderPaint);

      final innerRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: billWidth * 0.85,
          height: billHeight * 0.75,
        ),
        const Radius.circular(2),
      );
      final innerPaint = Paint()
        ..color = billBorder.withValues(alpha: opacity * 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5;
      canvas.drawRRect(innerRect, innerPaint);

      final amountText = ['¥1000', '¥5000', '¥10000'][i];
      final textPainter = TextPainter(
        text: TextSpan(
          text: amountText,
          style: TextStyle(
            color: billText.withValues(alpha: opacity * 0.8),
            fontSize: billHeight * 0.25,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );

      canvas.restore();
    }
  }

  void _drawSparkles(
    Canvas canvas,
    Size size,
    Random random, {
    required Color sparkleColor,
  }) {
    for (int i = 0; i < 20; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final sparkleSize = 3.0 + random.nextDouble() * 6.0;
      final opacity = (0.06 + random.nextDouble() * 0.25) *
          (0.5 + 0.5 * sin(animationValue * 2 * pi + i));

      final sparklePaint = Paint()
        ..color = sparkleColor.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      _drawStar(canvas, Offset(x, y), sparkleSize, sparklePaint);
    }
  }

  void _drawStar(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    for (int i = 0; i < 4; i++) {
      final angle = i * pi / 2;
      final outerX = center.dx + cos(angle) * size;
      final outerY = center.dy + sin(angle) * size;
      final innerAngle = angle + pi / 4;
      final innerX = center.dx + cos(innerAngle) * size * 0.3;
      final innerY = center.dy + sin(innerAngle) * size * 0.3;

      if (i == 0) {
        path.moveTo(outerX, outerY);
      } else {
        path.lineTo(outerX, outerY);
      }
      path.lineTo(innerX, innerY);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(MoneyBackgroundPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.isDark != isDark;
  }
}

/// アニメーション付きのお金背景ウィジェット
///
/// テーマのbrightnessに応じてライト／ダークの背景を自動切替。
class MoneyBackground extends StatefulWidget {
  final Widget child;

  const MoneyBackground({super.key, required this.child});

  @override
  State<MoneyBackground> createState() => _MoneyBackgroundState();
}

class _MoneyBackgroundState extends State<MoneyBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 8),
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
          painter: MoneyBackgroundPainter(
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
