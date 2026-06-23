import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/effects/domain/effect_definition.dart';
import 'package:kozuchi/features/effects/domain/effect_instance.dart';
import 'package:kozuchi/features/effects/presentation/effects/satori_glow_effect.dart';

void main() {
  group('SatoriGlowEffect', () {
    final _definition = const EffectDefinition(
      name: 'full_glow',
      duration: Duration(seconds: 3),
      isFullScreen: true,
    );

    EffectInstance _makeInstance({Duration? customDuration}) {
      return EffectInstance(
        id: 'test-glow-1',
        definition: customDuration != null
            ? EffectDefinition(
                name: 'full_glow',
                duration: customDuration,
                isFullScreen: true,
              )
            : _definition,
        position: Offset.zero,
      );
    }

    testWidgets('全画面を覆うContainerを持つ', (tester) async {
      final instance = _makeInstance();

      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              const Scaffold(body: Center(child: Text('背景'))),
              SatoriGlowEffect(instance: instance),
            ],
          ),
        ),
      );

      // Positioned.fill が使われていることを確認（全画面カバー）
      expect(find.byType(SatoriGlowEffect), findsOneWidget);

      // 背景Widgetも描画されている（IgnorePointerのおかげで覆い隠さない）
      expect(find.text('背景'), findsOneWidget);
    });

    testWidgets('初期フレームでは透明度が低い（ほぼ見えない）', (tester) async {
      final instance = _makeInstance();

      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              const Scaffold(body: Center(child: Text('背景'))),
              SatoriGlowEffect(instance: instance),
            ],
          ),
        ),
      );

      // 初期フレーム（t=0）: Opacityはほぼ0のはず
      final opacityFinder = find.byType(Opacity);
      expect(opacityFinder, findsOneWidget);
      final Opacity opacity = tester.widget(opacityFinder);
      // アニメーション開始直後はほぼ透明 (0に近い)
      expect(opacity.opacity, lessThan(0.1));
    });

    testWidgets('0.5秒後にopacityが上がる（立ち上がりフェーズ）', (tester) async {
      final instance = _makeInstance();

      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              const Scaffold(body: Center(child: Text('背景'))),
              SatoriGlowEffect(instance: instance),
            ],
          ),
        ),
      );

      // 0.5秒経過（立ち上がりが完了するタイミング）
      await tester.pump(const Duration(milliseconds: 500));

      final Opacity opacity = tester.widget(find.byType(Opacity));
      // 立ち上がり完了後は高い透明度 (15%経過 → 1.0近く)
      expect(opacity.opacity, greaterThan(0.8));
    });

    testWidgets('duration経過後に完全に透明化する', (tester) async {
      final instance = _makeInstance(customDuration: const Duration(milliseconds: 300));

      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              const Scaffold(body: Center(child: Text('背景'))),
              SatoriGlowEffect(instance: instance),
            ],
          ),
        ),
      );

      // 持続時間を過ぎるまで進める
      await tester.pump(const Duration(milliseconds: 400));

      final Opacity opacity = tester.widget(find.byType(Opacity));
      // duration経過後はopacityが0に戻る
      expect(opacity.opacity, lessThan(0.05));
    });

    testWidgets('IgnorePointerにより下層のタップを妨げない', (tester) async {
      bool tapped = false;
      final instance = _makeInstance();

      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              Scaffold(
                body: Center(
                  child: GestureDetector(
                    onTap: () => tapped = true,
                    child: const Text('タップして'),
                  ),
                ),
              ),
              SatoriGlowEffect(instance: instance),
            ],
          ),
        ),
      );

      await tester.tap(find.text('タップして'));
      await tester.pump();

      expect(tapped, true);
    });
  });
}
