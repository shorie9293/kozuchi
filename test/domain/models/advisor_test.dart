import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/advisor.dart';

void main() {
  group('Advisor', () {
    test('四天のアドバイザーが定義されている', () {
      expect(Advisor.values.length, 4);
      expect(Advisor.values, contains(Advisor.daikokuten));
      expect(Advisor.values, contains(Advisor.benzaiten));
      expect(Advisor.values, contains(Advisor.bishamonten));
      expect(Advisor.values, contains(Advisor.kichijoten));
    });

    test('大黒天は福・食・財を領分とする', () {
      expect(Advisor.daikokuten.domain, '福・食・財');
      expect(Advisor.daikokuten.label, '大黒天');
    });

    test('弁財天は学び・芸術を領分とする', () {
      expect(Advisor.benzaiten.domain, '学び・芸術');
      expect(Advisor.benzaiten.label, '弁財天');
    });

    test('毘沙門天は戦い・勝負を領分とする', () {
      expect(Advisor.bishamonten.domain, '戦い・勝負');
      expect(Advisor.bishamonten.label, '毘沙門天');
    });

    test('吉祥天は美・幸福を領分とする', () {
      expect(Advisor.kichijoten.domain, '美・幸福');
      expect(Advisor.kichijoten.label, '吉祥天');
    });

    group('役割・加護（v2.0刷新: 意味の再定義）', () {
      test('各大神は役割(role)と加護(blessing)の説明を持つ', () {
        for (final deity in Advisor.values) {
          expect(deity.role, isNotEmpty);
          expect(deity.blessing, isNotEmpty);
          expect(deity.effect, isNotEmpty);
        }
      });

      test('加護倍率は表示テキストに反映される', () {
        expect(Advisor.daikokuten.expMultiplierText, 'x1.0');
        expect(Advisor.benzaiten.expMultiplierText, 'x1.1');
        expect(Advisor.bishamonten.expMultiplierText, 'x1.2');
        expect(Advisor.kichijoten.expMultiplierText, 'x1.0');
      });

      test('毘沙門天が最大の加護倍率(1.2)を持つ', () {
        final maxMult = Advisor.values
            .map((d) => d.expMultiplier)
            .reduce((a, b) => a > b ? a : b);
        expect(maxMult, Advisor.bishamonten.expMultiplier);
      });
    });
  });
}
