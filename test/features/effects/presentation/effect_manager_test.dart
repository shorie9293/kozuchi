import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/effects/domain/effect_instance.dart';
import 'package:kozuchi/features/effects/data/effect_catalog.dart';
import 'package:kozuchi/features/effects/presentation/effect_manager.dart';
import 'package:kozuchi/features/satori/domain/satori_change_event.dart';
import 'package:kozuchi/features/satori/data/satori_event_dispatcher.dart';

/// テスト用のシンプルなエフェクト表示Widget
class _TestEffectWidget extends StatelessWidget {
  final EffectInstance instance;
  const _TestEffectWidget({required this.instance});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: instance.position.dx,
      top: instance.position.dy,
      child: Text('✨${instance.definition.name}'),
    );
  }
}

void main() {
  group('EffectManager', () {
    testWidgets('EffectManager.of(context)でstateを取得できる', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EffectManager(
            catalog: EffectCatalog.defaultCatalog(),
            effectBuilder: (_) => const SizedBox.shrink(),
            child: const Scaffold(body: Text('test')),
          ),
        ),
      );

      final state = tester.state<EffectManagerState>(
        find.byType(EffectManager),
      );
      expect(state, isNotNull);
      expect(state.activeEffects, isEmpty);
    });

    testWidgets('playEffectでエフェクトが追加される', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EffectManager(
            catalog: EffectCatalog.defaultCatalog(),
            effectBuilder: (instance) => _TestEffectWidget(instance: instance),
            child: const Scaffold(body: Text('test')),
          ),
        ),
      );

      final state = tester.state<EffectManagerState>(
        find.byType(EffectManager),
      );
      expect(state.activeEffects, isEmpty);

      state.playEffect('coin_scatter', const Offset(100, 200));
      await tester.pump();

      expect(state.activeEffects.length, 1);
      expect(state.activeEffects.first.definition.name, 'coin_scatter');
      expect(state.activeEffects.first.position, const Offset(100, 200));
      // エフェクトWidgetが表示されている
      expect(find.text('✨coin_scatter'), findsOneWidget);
    });

    testWidgets('複数エフェクトを同時に再生できる', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EffectManager(
            catalog: EffectCatalog.defaultCatalog(),
            effectBuilder: (instance) => _TestEffectWidget(instance: instance),
            child: const Scaffold(body: Text('test')),
          ),
        ),
      );

      final state = tester.state<EffectManagerState>(
        find.byType(EffectManager),
      );

      state.playEffect('coin_scatter', const Offset(50, 50));
      state.playEffect('coin_scatter', const Offset(200, 300));
      await tester.pump();

      expect(state.activeEffects.length, 2);
      expect(find.text('✨coin_scatter'), findsNWidgets(2));
    });

    testWidgets('duration経過後にエフェクトが自動消滅する', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EffectManager(
            catalog: EffectCatalog.defaultCatalog(),
            effectBuilder: (instance) => _TestEffectWidget(instance: instance),
            child: const Scaffold(body: Text('test')),
          ),
        ),
      );

      final state = tester.state<EffectManagerState>(
        find.byType(EffectManager),
      );

      // duration=0のエフェクト：即座にスケジュールされ、pumpで消滅
      state.playEffect('test_flash', const Offset(10, 10));
      expect(state.activeEffects.length, 1); // 追加直後は存在
      // Duration.zero の Timer は偽装クロックを進めると発火する
      await tester.pump(const Duration(milliseconds: 1));
      expect(state.activeEffects, isEmpty);
    });

    testWidgets('存在しないエフェクト名は無視される（例外を投げない）', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EffectManager(
            catalog: EffectCatalog.defaultCatalog(),
            effectBuilder: (instance) => _TestEffectWidget(instance: instance),
            child: const Scaffold(body: Text('test')),
          ),
        ),
      );

      final state = tester.state<EffectManagerState>(
        find.byType(EffectManager),
      );

      state.playEffect('nonexistent_effect', Offset.zero);
      await tester.pump();

      // カタログにないエフェクトは追加されない
      expect(state.activeEffects, isEmpty);
    });

    testWidgets('ボタンタップでプレースホルダーエフェクトが発火する（受入テスト）',
        (tester) async {
      // テスト用のエフェクトビルダー：PlaceholderEffectを使用
      Widget buildEffect(EffectInstance instance) {
        return Positioned(
          left: instance.position.dx,
          top: instance.position.dy,
          child: Text('💠${instance.definition.name}'),
        );
      }

      await tester.pumpWidget(
        MaterialApp(
          home: EffectManager(
            catalog: EffectCatalog.defaultCatalog(),
            effectBuilder: buildEffect,
            child: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      EffectManager.of(context).playEffect(
                        'placeholder',
                        const Offset(100, 300),
                      );
                    },
                    child: const Text('発火'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // ボタンが存在することを確認
      expect(find.text('発火'), findsOneWidget);
      // まだエフェクトはない
      expect(find.text('💠placeholder'), findsNothing);

      // ボタンをタップ
      await tester.tap(find.text('発火'));
      await tester.pump();

      // エフェクトが表示された
      expect(find.text('💠placeholder'), findsOneWidget);

      // duration経過後（1.5秒）にエフェクト消滅
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('💠placeholder'), findsNothing);
    });

    group('SATORI MAX グロー発動', () {
      // SATORIイベントディスパッチャーをテスト前にクリーンアップ
      setUp(() {
        SatoriEventDispatcher.instance.removeAllListeners();
      });

      testWidgets('SATORIレベルMAX到達でfull_glowが発動する', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: EffectManager(
              catalog: EffectCatalog.defaultCatalog(),
              effectBuilder: (instance) =>
                  _TestEffectWidget(instance: instance),
              child: const Scaffold(body: Text('test')),
            ),
          ),
        );

        final state = tester.state<EffectManagerState>(
          find.byType(EffectManager),
        );
        expect(state.activeEffects, isEmpty);

        // SATORI MAXイベントを発行: EXP 50→100 (engi→kuu)
        SatoriEventDispatcher.instance.dispatch(
          SatoriChangeEvent(
            direction: SatoriDirection.increase,
            reason: '究極の悟り — 所有の幻を見破る',
            oldValue: 50,
            newValue: 100,
            delta: 50,
          ),
        );

        // setStateがスケジュールされたのでpump
        await tester.pump();

        // full_glowエフェクトが追加されている
        expect(state.activeEffects.length, 1);
        expect(state.activeEffects.first.definition.name, 'full_glow');
        expect(find.text('✨full_glow'), findsOneWidget);
      });

      testWidgets('通常のSATORI増加ではfull_glowは発動しない', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: EffectManager(
              catalog: EffectCatalog.defaultCatalog(),
              effectBuilder: (instance) =>
                  _TestEffectWidget(instance: instance),
              child: const Scaffold(body: Text('test')),
            ),
          ),
        );

        final state = tester.state<EffectManagerState>(
          find.byType(EffectManager),
        );

        // 通常の増加: EXP 10→30 (両方ともshoTenborin)
        SatoriEventDispatcher.instance.dispatch(
          SatoriChangeEvent(
            direction: SatoriDirection.increase,
            reason: '善き布施の実践',
            oldValue: 10,
            newValue: 30,
            delta: 20,
          ),
        );

        await tester.pump();

        // full_glowは発動しない
        expect(state.activeEffects, isEmpty);
      });

      testWidgets('SATORI減少ではfull_glowは発動しない', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: EffectManager(
              catalog: EffectCatalog.defaultCatalog(),
              effectBuilder: (instance) =>
                  _TestEffectWidget(instance: instance),
              child: const Scaffold(body: Text('test')),
            ),
          ),
        );

        final state = tester.state<EffectManagerState>(
          find.byType(EffectManager),
        );

        // SATORI減少: EXP 120→70 (kuu→engi)
        SatoriEventDispatcher.instance.dispatch(
          SatoriChangeEvent(
            direction: SatoriDirection.decrease,
            reason: '執着の逆戻り',
            oldValue: 120,
            newValue: 70,
            delta: 50,
          ),
        );

        await tester.pump();

        // full_glowは発動しない
        expect(state.activeEffects, isEmpty);
      });

      testWidgets('既にkuu到達済みの増加ではfull_glowは再発動しない',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: EffectManager(
              catalog: EffectCatalog.defaultCatalog(),
              effectBuilder: (instance) =>
                  _TestEffectWidget(instance: instance),
              child: const Scaffold(body: Text('test')),
            ),
          ),
        );

        final state = tester.state<EffectManagerState>(
          find.byType(EffectManager),
        );

        // kuu→kuuの増加: 既にkuu状態
        SatoriEventDispatcher.instance.dispatch(
          SatoriChangeEvent(
            direction: SatoriDirection.increase,
            reason: '善き布施の実践',
            oldValue: 120,
            newValue: 150,
            delta: 30,
          ),
        );

        await tester.pump();

        // 既にkuuなので発動しない
        expect(state.activeEffects, isEmpty);
      });
    });

    group('喜捨（寄付）成功時の light_pillar 発動', () {
      setUp(() {
        SatoriEventDispatcher.instance.removeAllListeners();
      });

      testWidgets('理由に「喜捨」を含むSATORI増加でlight_pillarが発動する',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: EffectManager(
              catalog: EffectCatalog.defaultCatalog(),
              effectBuilder: (instance) =>
                  _TestEffectWidget(instance: instance),
              child: const Scaffold(body: Text('test')),
            ),
          ),
        );

        final state = tester.state<EffectManagerState>(
          find.byType(EffectManager),
        );
        expect(state.activeEffects, isEmpty);

        // 「惜しみなき喜捨」イベントを発行
        SatoriEventDispatcher.instance.dispatch(
          const SatoriChangeEvent(
            direction: SatoriDirection.increase,
            reason: '惜しみなき喜捨',
            oldValue: 100,
            newValue: 135,
            delta: 35,
          ),
        );

        await tester.pump();

        // light_pillarエフェクトが追加されている
        expect(state.activeEffects.length, 1);
        expect(state.activeEffects.first.definition.name, 'light_pillar');
        expect(find.text('✨light_pillar'), findsOneWidget);
      });

      testWidgets('理由に「喜捨」を含まない通常増加ではlight_pillarは発動しない',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: EffectManager(
              catalog: EffectCatalog.defaultCatalog(),
              effectBuilder: (instance) =>
                  _TestEffectWidget(instance: instance),
              child: const Scaffold(body: Text('test')),
            ),
          ),
        );

        final state = tester.state<EffectManagerState>(
          find.byType(EffectManager),
        );

        // 通常の理由（「善き布施の実践」）
        SatoriEventDispatcher.instance.dispatch(
          const SatoriChangeEvent(
            direction: SatoriDirection.increase,
            reason: '善き布施の実践',
            oldValue: 10,
            newValue: 30,
            delta: 20,
          ),
        );

        await tester.pump();

        // light_pillarは発動しない
        expect(state.activeEffects, isEmpty);
      });

      testWidgets('SATORI減少ではlight_pillarは発動しない', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: EffectManager(
              catalog: EffectCatalog.defaultCatalog(),
              effectBuilder: (instance) =>
                  _TestEffectWidget(instance: instance),
              child: const Scaffold(body: Text('test')),
            ),
          ),
        );

        final state = tester.state<EffectManagerState>(
          find.byType(EffectManager),
        );

        // 理由に「喜捨」が含まれていても減少なら発動しない
        SatoriEventDispatcher.instance.dispatch(
          const SatoriChangeEvent(
            direction: SatoriDirection.decrease,
            reason: '喜捨の反動',
            oldValue: 120,
            newValue: 70,
            delta: 50,
          ),
        );

        await tester.pump();

        // light_pillarは発動しない
        expect(state.activeEffects, isEmpty);
      });

      testWidgets('light_pillarエフェクトがduration経過後に消滅する',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: EffectManager(
              catalog: EffectCatalog.defaultCatalog(),
              effectBuilder: (instance) =>
                  _TestEffectWidget(instance: instance),
              child: const Scaffold(body: Text('test')),
            ),
          ),
        );

        final state = tester.state<EffectManagerState>(
          find.byType(EffectManager),
        );

        // 「惜しみなき喜捨」イベントを発行
        SatoriEventDispatcher.instance.dispatch(
          const SatoriChangeEvent(
            direction: SatoriDirection.increase,
            reason: '惜しみなき喜捨',
            oldValue: 100,
            newValue: 135,
            delta: 35,
          ),
        );

        await tester.pump();
        expect(state.activeEffects.length, 1);
        expect(find.text('✨light_pillar'), findsOneWidget);

        // duration（2.5秒）経過後に消滅
        await tester.pump(const Duration(seconds: 3));
        expect(state.activeEffects, isEmpty);
        expect(find.text('✨light_pillar'), findsNothing);
      });

      testWidgets('「喜捨」を含む他の理由文字列でも発動する', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: EffectManager(
              catalog: EffectCatalog.defaultCatalog(),
              effectBuilder: (instance) =>
                  _TestEffectWidget(instance: instance),
              child: const Scaffold(body: Text('test')),
            ),
          ),
        );

        final state = tester.state<EffectManagerState>(
          find.byType(EffectManager),
        );

        // 「気前よき布施」には「喜捨」が含まれない→発動しないことを確認済み
        // 「大いなる喜捨の恵み」には「喜捨」が含まれる→発動する
        SatoriEventDispatcher.instance.dispatch(
          const SatoriChangeEvent(
            direction: SatoriDirection.increase,
            reason: '大いなる喜捨の恵み',
            oldValue: 50,
            newValue: 85,
            delta: 35,
          ),
        );

        await tester.pump();

        expect(state.activeEffects.length, 1);
        expect(state.activeEffects.first.definition.name, 'light_pillar');
      });
    });
  });
}
