import 'package:flutter/material.dart';
import 'dart:math';

/// お金を楽しむコンセプトの明るい背景ペインター
/// 金貨・札・キラキラエフェクトを描画
class MoneyBackgroundPainter extends CustomPainter {
  final double animationValue;

  MoneyBackgroundPainter({this.animationValue = 0.0});

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(42); // 固定シードで再現性確保

    // 背景グラデーション（温かみのあるゴールド系）
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFFFFF8E1), // 薄いクリーム
          const Color(0xFFFFECB3), // 薄いゴールド
          const Color(0xFFFFE0B2), // 薄いオレンジ
          const Color(0xFFFFF3E0), // 薄いピーチ
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 金貨を散りばめる
    _drawCoins(canvas, size, random);

    // お札を散りばめる
    _drawBills(canvas, size, random);

    // キラキラエフェクト
    _drawSparkles(canvas, size, random);
  }

  void _drawCoins(Canvas canvas, Size size, Random random) {
    // 12個の金貨をランダム配置
    for (int i = 0; i < 12; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = 12.0 + random.nextDouble() * 15.0;
      final opacity = 0.15 + random.nextDouble() * 0.25;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(random.nextDouble() * pi * 0.3 - 0.15); // 少し傾ける

      // 金貨の円
      final coinPaintWithOpacity = Paint()
        ..shader = RadialGradient(
          colors: [
            Color.fromRGBO(255, 215, 0, opacity),
            Color.fromRGBO(255, 160, 0, opacity),
            Color.fromRGBO(255, 143, 0, opacity * 0.8),
          ],
          stops: [0.0, 0.6, 1.0],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius));

      canvas.drawCircle(Offset.zero, radius, coinPaintWithOpacity);

      // 金貨の縁
      final borderWithOpacity = Paint()
        ..color = Color.fromRGBO(230, 81, 0, opacity * 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(Offset.zero, radius, borderWithOpacity);

      // 金貨の中央の模様（小円）
      final innerPaint = Paint()
        ..color = Color.fromRGBO(255, 193, 7, opacity * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawCircle(Offset.zero, radius * 0.6, innerPaint);

      // ¥マーク
      final textPainter = TextPainter(
        text: TextSpan(
          text: '¥',
          style: TextStyle(
            color: Color.fromRGBO(230, 81, 0, opacity * 0.7),
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

  void _drawBills(Canvas canvas, Size size, Random random) {
    // お札を3枚配置
    for (int i = 0; i < 3; i++) {
      final x = random.nextDouble() * size.width * 0.8 + size.width * 0.1;
      final y = random.nextDouble() * size.height * 0.8 + size.height * 0.1;
      final opacity = 0.08 + random.nextDouble() * 0.12;
      final angle = random.nextDouble() * 0.4 - 0.2;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);

      // お札のサイズ
      final billWidth = 80.0 + random.nextDouble() * 40.0;
      final billHeight = billWidth * 0.5;

      // お札の背景
      final billPaint = Paint()
        ..color = Color.fromRGBO(129, 199, 132, opacity) // 緑系
        ..style = PaintingStyle.fill;
      final billRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: billWidth, height: billHeight),
        const Radius.circular(4),
      );
      canvas.drawRRect(billRect, billPaint);

      // お札の縁
      final billBorder = Paint()
        ..color = Color.fromRGBO(56, 142, 60, opacity * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawRRect(billRect, billBorder);

      // 内側の模様
      final innerRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: billWidth * 0.85,
          height: billHeight * 0.75,
        ),
        const Radius.circular(2),
      );
      final innerPaint = Paint()
        ..color = Color.fromRGBO(56, 142, 60, opacity * 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5;
      canvas.drawRRect(innerRect, innerPaint);

      // 金額テキスト
      final amountText = ['¥1000', '¥5000', '¥10000'][i];
      final textPainter = TextPainter(
        text: TextSpan(
          text: amountText,
          style: TextStyle(
            color: Color.fromRGBO(27, 94, 32, opacity * 0.8),
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

  void _drawSparkles(Canvas canvas, Size size, Random random) {
    // キラキラエフェクト（星型）
    for (int i = 0; i < 20; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final sparkleSize = 3.0 + random.nextDouble() * 6.0;
      final opacity = (0.1 + random.nextDouble() * 0.3) *
          (0.5 + 0.5 * sin(animationValue * 2 * pi + i));

      final sparklePaint = Paint()
        ..color = Color.fromRGBO(255, 215, 0, opacity) // ゴールド
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
    return oldDelegate.animationValue != animationValue;
  }
}

/// アニメーション付きのお金背景ウィジェット
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: MoneyBackgroundPainter(
            animationValue: _controller.value,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
