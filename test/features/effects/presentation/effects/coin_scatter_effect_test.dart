import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/effects/domain/effect_definition.dart';
import 'package:kozuchi/features/effects/domain/effect_instance.dart';
import 'package:kozuchi/features/effects/presentation/effects/coin_scatter_effect.dart';
import 'package:kozuchi/features/effects/presentation/effect_manager.dart';
import 'package:kozuchi/features/effects/data/effect_catalog.dart';

void main() {
  group('CoinScatterEffect', () {
    // テスト用の2秒エフェクト定義
    final definition = const EffectDefinition(
      name: 'coin_scatter',
      duration: Duration(seconds: 2),
      particleCount: 12,
    );

    EffectInstance makeInstance({Offset? position}) {
      return EffectInstance(
        id: 'test-coin-scatter',
        definition: definition,
        position: position ?? const Offset(100, 200),
      );
    }

    testWidgets('指定位置にCoinScatterEffectが表示される', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                CoinScatterEffect(instance: makeInstance()),
              ],
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(CoinScatterEffect), findsOneWidget);
    });

    testWidgets('アニメーションが進行してもWidgetは存在し続ける', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                CoinScatterEffect(instance: makeInstance()),
              ],
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(CoinScatterEffect), findsOneWidget);

      // duration経過後もWidget自体は存在する（EffectManager側で削除される）
      await tester.pump(const Duration(seconds: 3));
      expect(find.byType(CoinScatterEffect), findsOneWidget);
    });

    testWidgets('EffectManager経由でcoin_scatterエフェクトが発火する（統合テスト）',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EffectManager(
            catalog: EffectCatalog.defaultCatalog(),
            effectBuilder: (instance) {
              if (instance.definition.name == 'coin_scatter') {
                return CoinScatterEffect(instance: instance);
              }
              return const SizedBox.shrink();
            },
            child: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () {
                      EffectManager.of(context).playEffect(
                        'coin_scatter',
                        const Offset(150, 300),
                      );
                    },
                    child: const Text('支出'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // 初期状態：エフェクトなし
      await tester.pump();
      expect(find.byType(CoinScatterEffect), findsNothing);

      // ボタンタップでエフェクト発火
      await tester.tap(find.text('支出'));
      await tester.pump();

      // エフェクトが表示された
      expect(find.byType(CoinScatterEffect), findsOneWidget);

      // duration経過後（2秒）にエフェクト消滅
      await tester.pump(const Duration(seconds: 3));
      expect(find.byType(CoinScatterEffect), findsNothing);
    });

    testWidgets('コイン散布の各パーティクルが表示される（テキスト絵文字）', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                CoinScatterEffect(instance: makeInstance()),
              ],
            ),
          ),
        ),
      );

      await tester.pump();
      // コイン絵文字（💰, 🪙, 💸）のいずれかが表示されている
      // particleCount=12なので複数の絵文字が存在する
      final coin1 = find.text('💰');
      final coin2 = find.text('🪙');
      final coin3 = find.text('💸');

      // いずれかのコイン絵文字が表示されている
      final found =
          coin1.evaluate().length + coin2.evaluate().length + coin3.evaluate().length;
      expect(found, greaterThan(0));
    });
  });
}
