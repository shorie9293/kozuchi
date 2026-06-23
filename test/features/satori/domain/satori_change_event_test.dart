import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/satori/domain/satori_change_event.dart';

void main() {
  group('SatoriChangeEvent', () {
    test('全フィールドを保持する', () {
      const event = SatoriChangeEvent(
        direction: SatoriDirection.increase,
        reason: '善き布施の実践',
        oldValue: 10,
        newValue: 25,
        delta: 15,
        context: 'ライフプランナー',
      );

      expect(event.direction, SatoriDirection.increase);
      expect(event.reason, '善き布施の実践');
      expect(event.oldValue, 10);
      expect(event.newValue, 25);
      expect(event.delta, 15);
      expect(event.context, 'ライフプランナー');
    });

    test('toStringは矢印と理由と値の変遷を含む', () {
      const event = SatoriChangeEvent(
        direction: SatoriDirection.increase,
        reason: '深き内省の悟り',
        oldValue: 50,
        newValue: 70,
        delta: 20,
      );

      final str = event.toString();
      expect(str, contains('↑'));
      expect(str, contains('深き内省の悟り'));
      expect(str, contains('50'));
      expect(str, contains('70'));
    });

    test('減少イベントのtoStringは下矢印を含む', () {
      const event = SatoriChangeEvent(
        direction: SatoriDirection.decrease,
        reason: '執着の逆戻り',
        oldValue: 30,
        newValue: 20,
        delta: 10,
      );

      expect(event.toString(), contains('↓'));
    });

    test('同一値のイベントは等価', () {
      const a = SatoriChangeEvent(
        direction: SatoriDirection.increase,
        reason: 'test',
        oldValue: 0,
        newValue: 10,
        delta: 10,
      );
      const b = SatoriChangeEvent(
        direction: SatoriDirection.increase,
        reason: 'test',
        oldValue: 0,
        newValue: 10,
        delta: 10,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('異なるreasonは非等価', () {
      const a = SatoriChangeEvent(
        direction: SatoriDirection.increase,
        reason: 'A',
        oldValue: 0,
        newValue: 10,
        delta: 10,
      );
      const b = SatoriChangeEvent(
        direction: SatoriDirection.increase,
        reason: 'B',
        oldValue: 0,
        newValue: 10,
        delta: 10,
      );

      expect(a, isNot(equals(b)));
    });

    test('contextがnullでも作成できる', () {
      const event = SatoriChangeEvent(
        direction: SatoriDirection.increase,
        reason: 'test',
        oldValue: 0,
        newValue: 5,
        delta: 5,
      );

      expect(event.context, isNull);
    });
  });

  group('SatoriDirection', () {
    test('increaseとdecreaseの2値を持つ', () {
      expect(SatoriDirection.values.length, 2);
      expect(SatoriDirection.values, contains(SatoriDirection.increase));
      expect(SatoriDirection.values, contains(SatoriDirection.decrease));
    });
  });
}
