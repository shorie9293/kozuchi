import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/enlightenment_stage.dart';

void main() {
  group('EnlightenmentStage', () {
    test('3段階の開眼段階が定義されている', () {
      expect(EnlightenmentStage.values.length, 3);
      expect(EnlightenmentStage.values, contains(EnlightenmentStage.shoTenborin));
      expect(EnlightenmentStage.values, contains(EnlightenmentStage.engi));
      expect(EnlightenmentStage.values, contains(EnlightenmentStage.kuu));
    });

    test('初転法輪は初期段階である', () {
      expect(EnlightenmentStage.shoTenborin.label, '初転法輪');
      expect(EnlightenmentStage.shoTenborin.threshold, 0);
    });

    test('縁起は中域の段階である', () {
      expect(EnlightenmentStage.engi.label, '縁起');
      expect(EnlightenmentStage.engi.threshold, greaterThan(0));
    });

    test('空は最高段階である', () {
      expect(EnlightenmentStage.kuu.label, '空');
      expect(EnlightenmentStage.kuu.threshold, greaterThan(EnlightenmentStage.engi.threshold));
    });

    test('SATORI値から適切な開眼段階を判定できる', () {
      expect(EnlightenmentStage.fromSatori(0), EnlightenmentStage.shoTenborin);
      expect(EnlightenmentStage.fromSatori(30), EnlightenmentStage.shoTenborin);
      expect(EnlightenmentStage.fromSatori(50), EnlightenmentStage.engi);
      expect(EnlightenmentStage.fromSatori(80), EnlightenmentStage.engi);
      expect(EnlightenmentStage.fromSatori(100), EnlightenmentStage.kuu);
      expect(EnlightenmentStage.fromSatori(150), EnlightenmentStage.kuu);
    });
  });
}
