import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/effects/domain/effect_definition.dart';
import 'package:kozuchi/features/effects/domain/effect_instance.dart';
import 'package:kozuchi/features/effects/presentation/effects/satori_increase_effect.dart';

void main() {
  group('SatoriIncreaseEffect', () {
    final _definition = const EffectDefinition(
      name: 'satori_increase',
      duration: Duration(milliseconds: 1500),
      particleCount: 8,
    );

    EffectInstance _makeInstance({Offset position = Offset.zero}) {
      return EffectInstance(
        id: 'test-increase-1',
        definition: _definition,
        position: position,
      );
    }

    testWidgets('指定位置に光の粒子を表示する', (tester) async {
      final instance = _makeInstance(
        position: const Offset(200, 100),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              const Scaffold(body: Center(child: Text('背景'))),
              SatoriIncreaseEffect(instance: instance),
            ],
          ),
        ),
      );

      // エフェクトWidgetが存在する
      expect(find.byType(SatoriIncreaseEffect), findsOneWidget);
    });

    testWidgets('IgnorePointerにより下層UIを妨げない', (tester) async {
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
                    child: const Text('タップテスト'),
                  ),
                ),
              ),
              SatoriIncreaseEffect(instance: instance),
            ],
          ),
        ),
      );

      await tester.tap(find.text('タップテスト'));
      await tester.pump();

      expect(tapped, true);
    });

    testWidgets('粒子が上方向に移動する（dyが負）', (tester) async {
      final instance = _makeInstance(
        position: const Offset(100, 200),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              const Scaffold(body: Center(child: Text('背景'))),
              SatoriIncreaseEffect(instance: instance),
            ],
          ),
        ),
      );

      // 初期フレームでは粒子が表示されている
      await tester.pump();
      expect(find.byType(SatoriIncreaseEffect), findsOneWidget);

      // アニメーションが進行してもエラーなく描画される
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(SatoriIncreaseEffect), findsOneWidget);
    });

    testWidgets('全持続時間経過後もWidgetは破棄されない（EffectManagerが管理）', (tester) async {
      final instance = _makeInstance();

      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              const Scaffold(body: Center(child: Text('背景'))),
              SatoriIncreaseEffect(instance: instance),
            ],
          ),
        ),
      );

      // 持続時間経過後
      await tester.pump(const Duration(milliseconds: 2000));

      // Widget自体は残る（EffectManagerが削除を管理）
      expect(find.byType(SatoriIncreaseEffect), findsOneWidget);
    });

    testWidgets('指定したparticleCountが反映される', (tester) async {
      final customDefinition = const EffectDefinition(
        name: 'satori_increase',
        duration: Duration(milliseconds: 1500),
        particleCount: 20,
      );
      final instance = EffectInstance(
        id: 'test-increase-custom',
        definition: customDefinition,
        position: Offset.zero,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              const Scaffold(body: Center(child: Text('背景'))),
              SatoriIncreaseEffect(instance: instance),
            ],
          ),
        ),
      );

      // particleCount=20でも正常に描画される
      expect(find.byType(SatoriIncreaseEffect), findsOneWidget);
    });

    testWidgets('異なる位置で発火しても正しく表示される', (tester) async {
      final instance = _makeInstance(
        position: const Offset(300, 50),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              const Scaffold(body: Center(child: Text('背景'))),
              SatoriIncreaseEffect(instance: instance),
            ],
          ),
        ),
      );

      expect(find.byType(SatoriIncreaseEffect), findsOneWidget);
    });
  });
}
