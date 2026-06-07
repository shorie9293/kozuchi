import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/guardian_deity.dart';

void main() {
  group('GuardianDeity', () {
    test('四天の守護神が定義されている', () {
      expect(GuardianDeity.values.length, 4);
      expect(GuardianDeity.values, contains(GuardianDeity.daikokuten));
      expect(GuardianDeity.values, contains(GuardianDeity.benzaiten));
      expect(GuardianDeity.values, contains(GuardianDeity.bishamonten));
      expect(GuardianDeity.values, contains(GuardianDeity.kisshoten));
    });

    test('大黒天は福・食・財を領分とする', () {
      expect(GuardianDeity.daikokuten.domain, '福・食・財');
      expect(GuardianDeity.daikokuten.label, '大黒天');
    });

    test('弁財天は学び・芸術を領分とする', () {
      expect(GuardianDeity.benzaiten.domain, '学び・芸術');
      expect(GuardianDeity.benzaiten.label, '弁財天');
    });

    test('毘沙門天は戦い・勝負を領分とする', () {
      expect(GuardianDeity.bishamonten.domain, '戦い・勝負');
      expect(GuardianDeity.bishamonten.label, '毘沙門天');
    });

    test('吉祥天は美・幸福を領分とする', () {
      expect(GuardianDeity.kisshoten.domain, '美・幸福');
      expect(GuardianDeity.kisshoten.label, '吉祥天');
    });
  });
}
