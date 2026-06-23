import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/effects/domain/effect_definition.dart';
import 'package:kozuchi/features/effects/domain/effect_instance.dart';

void main() {
  group('EffectDefinition', () {
    test('基本的なエフェクト定義を生成できる', () {
      final def = EffectDefinition(
        name: 'coin_scatter',
        duration: const Duration(seconds: 2),
      );
      expect(def.name, 'coin_scatter');
      expect(def.duration, const Duration(seconds: 2));
      expect(def.particleCount, isNull);
      expect(def.isFullScreen, false);
    });

    test('パーティクル数付きのエフェクト定義を生成できる', () {
      final def = EffectDefinition(
        name: 'cherry_snow',
        duration: const Duration(seconds: 3),
        particleCount: 30,
      );
      expect(def.particleCount, 30);
    });

    test('全画面エフェクトを指定できる', () {
      final def = EffectDefinition(
        name: 'full_glow',
        duration: const Duration(seconds: 3),
        isFullScreen: true,
      );
      expect(def.isFullScreen, true);
    });

    test('同じエフェクト名の定義は等価である', () {
      final a = EffectDefinition(name: 'test', duration: const Duration(seconds: 1));
      final b = EffectDefinition(name: 'test', duration: const Duration(seconds: 1));
      expect(a, equals(b));
    });

    test('開始時間から期間を過ぎたら期限切れと判定される', () {
      // durationを0にすると即座に期限切れ = インスタンス生成時点で終了
      final def = EffectDefinition(name: 'flash', duration: Duration.zero);
      final instance = EffectInstance(
        id: 'inst-1',
        definition: def,
        position: const Offset(100, 200),
      );
      expect(instance.isExpired, true);
    });

    test('duration内であれば期限切れではない', () {
      final def = EffectDefinition(name: 'long', duration: const Duration(hours: 1));
      final instance = EffectInstance(
        id: 'inst-2',
        definition: def,
        position: Offset.zero,
      );
      expect(instance.isExpired, false);
    });
  });

  group('EffectInstance', () {
    test('ユニークIDと位置情報を持つ', () {
      final instance = EffectInstance(
        id: 'abc-123',
        definition: EffectDefinition(
          name: 'test',
          duration: const Duration(seconds: 1),
        ),
        position: const Offset(50, 100),
      );
      expect(instance.id, 'abc-123');
      expect(instance.position, const Offset(50, 100));
      expect(instance.definition.name, 'test');
    });

    test('startTimeは生成時点の現在時刻である', () {
      final before = DateTime.now();
      final instance = EffectInstance(
        id: 'time-test',
        definition: EffectDefinition(
          name: 't',
          duration: const Duration(seconds: 1),
        ),
        position: Offset.zero,
      );
      final after = DateTime.now();
      expect(
        instance.startTime.isAfter(before) || instance.startTime == before,
        true,
      );
      expect(
        instance.startTime.isBefore(after) || instance.startTime == after,
        true,
      );
    });
  });
}
