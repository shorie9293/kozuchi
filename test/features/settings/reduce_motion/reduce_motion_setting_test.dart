import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/core/theme/reduce_motion_setting.dart';

void main() {
  group('ReduceMotionSetting', () {
    test('fromStorageKey: 未知キー・null は system に倒す', () {
      expect(ReduceMotionSetting.fromStorageKey(null),
          ReduceMotionSetting.system);
      expect(ReduceMotionSetting.fromStorageKey(''),
          ReduceMotionSetting.system);
      expect(ReduceMotionSetting.fromStorageKey('unknown'),
          ReduceMotionSetting.system);
    });

    test('fromStorageKey: 定義済みキーは対応する設定へ復元する', () {
      expect(ReduceMotionSetting.fromStorageKey('system'),
          ReduceMotionSetting.system);
      expect(
          ReduceMotionSetting.fromStorageKey('off'), ReduceMotionSetting.off);
      expect(ReduceMotionSetting.fromStorageKey('on'), ReduceMotionSetting.on);
    });

    test('next: system→off→on→system の巡回', () {
      expect(ReduceMotionSetting.system.next, ReduceMotionSetting.off);
      expect(ReduceMotionSetting.off.next, ReduceMotionSetting.on);
      expect(ReduceMotionSetting.on.next, ReduceMotionSetting.system);
    });

    test('forceDisableAnimations: on=true / off=false / system=null', () {
      expect(ReduceMotionSetting.on.forceDisableAnimations, isTrue);
      expect(ReduceMotionSetting.off.forceDisableAnimations, isFalse);
      expect(ReduceMotionSetting.system.forceDisableAnimations, isNull);
    });

    test('storageKey・label・icon が3択それぞれで定義されている', () {
      expect(ReduceMotionSetting.values.length, 3);
      expect(ReduceMotionSetting.system.storageKey, 'system');
      expect(ReduceMotionSetting.off.storageKey, 'off');
      expect(ReduceMotionSetting.on.storageKey, 'on');
      expect(ReduceMotionSetting.system.label, 'システムに従う');
      expect(ReduceMotionSetting.off.label, '動きを有効');
      expect(ReduceMotionSetting.on.label, '動きを減らす');
      final labels =
          ReduceMotionSetting.values.map((e) => e.label).toSet();
      expect(labels.length, 3);
      final icons = ReduceMotionSetting.values.map((e) => e.icon).toSet();
      expect(icons.length, 3);
    });
  });

  group('applyReduceMotion', () {
    test('system は MediaQueryData をそのまま返す（端末設定を尊重）', () {
      const data = MediaQueryData(disableAnimations: true);
      final applied = applyReduceMotion(data, ReduceMotionSetting.system);
      expect(applied.disableAnimations, isTrue);
      expect(identical(applied, data), isTrue);

      const data2 = MediaQueryData();
      final applied2 = applyReduceMotion(data2, ReduceMotionSetting.system);
      expect(applied2.disableAnimations, isFalse);
      expect(identical(applied2, data2), isTrue);
    });

    test('on は disableAnimations=true を強制する', () {
      const data = MediaQueryData();
      expect(
          applyReduceMotion(data, ReduceMotionSetting.on).disableAnimations,
          isTrue);
    });

    test('off は disableAnimations=false を強制する（端末設定より優先）', () {
      const data = MediaQueryData(disableAnimations: true);
      expect(
          applyReduceMotion(data, ReduceMotionSetting.off).disableAnimations,
          isFalse);
    });

    test('強制時も textScaler 等の既存値は保持される', () {
      const data = MediaQueryData(
        textScaler: TextScaler.linear(1.25),
        disableAnimations: false,
      );
      final applied = applyReduceMotion(data, ReduceMotionSetting.on);
      expect(applied.textScaler, const TextScaler.linear(1.25));
      expect(applied.disableAnimations, isTrue);
    });
  });
}
