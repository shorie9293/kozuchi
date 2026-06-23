import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/effects/domain/effect_definition.dart';
import 'package:kozuchi/features/effects/domain/effect_instance.dart';
import 'package:kozuchi/features/effects/data/effect_catalog.dart';
import 'package:kozuchi/features/effects/presentation/effect_manager.dart';
import 'package:kozuchi/features/effects/presentation/effects/cherry_blizzard_effect.dart';

void main() {
  group('CherryBlizzardEffect', () {
    testWidgets('エフェクトがレンダリングされ、ピンク色の花びらが表示される',
        (tester) async {
      final catalog = EffectCatalog.defaultCatalog();
      final definition = catalog.lookup('cherry_snow')!;
      final instance = EffectInstance(
        id: 'test-cherry',
        definition: definition,
        position: const Offset(200, 400),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                CherryBlizzardEffect(instance: instance),
              ],
            ),
          ),
        ),
      );

      // 花びら（Container widgets）が複数表示されていることを確認
      // CherryBlizzardEffect は Stack + Positioned の花びら群を生成する
      await tester.pump();
      expect(find.byType(CherryBlizzardEffect), findsOneWidget);

      // 少なくとも何らかの花びらコンテナが存在する
      final petals = tester
          .widgetList<Positioned>(find.descendant(
            of: find.byType(CherryBlizzardEffect),
            matching: find.byType(Positioned),
          ))
          .toList();
      expect(petals.length, greaterThan(0),
          reason: '少なくとも1枚の花びらが表示されるべき');
    });

    testWidgets('定義されたパーティクル数（30）の花びらが生成される', (tester) async {
      final instance = EffectInstance(
        id: 'test-cherry-30',
        definition: const EffectDefinition(
          name: 'cherry_snow',
          duration: Duration(seconds: 3),
          particleCount: 30,
        ),
        position: const Offset(100, 200),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                CherryBlizzardEffect(instance: instance),
              ],
            ),
          ),
        ),
      );

      await tester.pump();
      final petals = tester
          .widgetList<Positioned>(find.descendant(
            of: find.byType(CherryBlizzardEffect),
            matching: find.byType(Positioned),
          ))
          .toList();
      expect(petals.length, 30);
    });

    testWidgets('EffectManager経由でcherry_snowエフェクトが発火できる',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EffectManager(
            catalog: EffectCatalog.defaultCatalog(),
            effectBuilder: (instance) {
              if (instance.definition.name == 'cherry_snow') {
                return CherryBlizzardEffect(instance: instance);
              }
              return const SizedBox.shrink();
            },
            child: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      EffectManager.of(context).playEffect(
                        'cherry_snow',
                        const Offset(150, 300),
                      );
                    },
                    child: const Text('入金'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // 初期状態ではエフェクトなし
      expect(find.byType(CherryBlizzardEffect), findsNothing);

      // ボタンタップでエフェクト発火
      await tester.tap(find.text('入金'));
      await tester.pump();

      // エフェクトが表示された
      expect(find.byType(CherryBlizzardEffect), findsOneWidget);

      // 3秒経過でエフェクト消滅
      await tester.pump(const Duration(seconds: 4));
      expect(find.byType(CherryBlizzardEffect), findsNothing);
    });

    testWidgets('2〜3秒のアニメーションが動作する', (tester) async {
      final instance = EffectInstance(
        id: 'test-anim',
        definition: const EffectDefinition(
          name: 'cherry_snow',
          duration: Duration(seconds: 3),
          particleCount: 5,
        ),
        position: const Offset(150, 300),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                CherryBlizzardEffect(instance: instance),
              ],
            ),
          ),
        ),
      );

      // 初期フレーム
      await tester.pump();
      expect(find.byType(CherryBlizzardEffect), findsOneWidget);

      // 途中のフレームでも表示されている（クラッシュしない）
      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.byType(CherryBlizzardEffect), findsOneWidget);

      // 終了フレーム
      await tester.pump(const Duration(milliseconds: 2000));
      // エフェクトはまだ存在する（EffectManagerが削除するまで）
      expect(find.byType(CherryBlizzardEffect), findsOneWidget);
    });
  });
}
