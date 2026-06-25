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
  });
}
