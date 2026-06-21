import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/level_stage.dart';

void main() {
  group('LevelStage', () {
    test('3段階の開眼段階が定義されている', () {
      expect(LevelStage.values.length, 3);
      expect(LevelStage.values, contains(LevelStage.shoTenborin));
      expect(LevelStage.values, contains(LevelStage.engi));
      expect(LevelStage.values, contains(LevelStage.kuu));
    });

    test('レベル1は初期段階である', () {
      expect(LevelStage.shoTenborin.label, 'レベル1');
      expect(LevelStage.shoTenborin.threshold, 0);
    });

    test('レベル2は中域の段階である', () {
      expect(LevelStage.engi.label, 'レベル2');
      expect(LevelStage.engi.threshold, greaterThan(0));
    });

    test('レベルMAXは最高段階である', () {
      expect(LevelStage.kuu.label, 'レベルMAX');
      expect(LevelStage.kuu.threshold, greaterThan(LevelStage.engi.threshold));
    });

    test('EXP値から適切な開眼段階を判定できる', () {
      expect(LevelStage.fromExp(0), LevelStage.shoTenborin);
      expect(LevelStage.fromExp(30), LevelStage.shoTenborin);
      expect(LevelStage.fromExp(50), LevelStage.engi);
      expect(LevelStage.fromExp(80), LevelStage.engi);
      expect(LevelStage.fromExp(100), LevelStage.kuu);
      expect(LevelStage.fromExp(150), LevelStage.kuu);
    });
  });
}
