import 'package:flutter/material.dart';

/// ピンチゾーン専用オーバーレイ
///
/// ピンチ状態（HPが生活防衛ライン以下）のとき、
/// 画面にモノクロフィルター + ヴィネット（視界狭窄）演出を適用する。
class PinchZoneOverlay extends StatelessWidget {
  /// ピンチ状態かどうか
  final bool isPinchState;

  /// 描画する子Widget
  final Widget child;

  const PinchZoneOverlay({
    super.key,
    required this.isPinchState,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!isPinchState) {
      return child;
    }

    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        // モノクロ（彩度0）変換行列
        0.2126, 0.7152, 0.0722, 0, 0, // R
        0.2126, 0.7152, 0.0722, 0, 0, // G
        0.2126, 0.7152, 0.0722, 0, 0, // B
        0,      0,      0,      1, 0, // A
      ]),
      child: Stack(
        key: const Key('pinch_zone_vignette_stack'),
        children: [
          child,
          // ヴィネット（四隅が暗くなる視界狭窄）
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                key: const Key('pinch_zone_vignette'),
                painter: _VignettePainter(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ヴィネット効果を描画するCustomPainter
class _VignettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 中心から放射状に広がるグラデーション。60%地点から暗くなるヴィネット
    const vignetteRadius = 0.6;

    final gradient = RadialGradient(
      center: Alignment.center,
      radius: vignetteRadius,
      colors: const [
        Colors.transparent,
        Colors.black54,
      ],
      stops: const [0.5, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect);

    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
