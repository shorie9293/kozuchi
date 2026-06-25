import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/effects/data/effect_catalog.dart';

void main() {
  group('EffectCatalog - guardian_switch', () {
    test('guardian_switch がデフォルトカタログに登録されている', () {
      final catalog = EffectCatalog.defaultCatalog();
      final definition = catalog.lookup('guardian_switch');
      expect(definition, isNotNull);
    });

    test('guardian_switch は全画面エフェクトである', () {
      final catalog = EffectCatalog.defaultCatalog();
      final definition = catalog.lookup('guardian_switch');
      expect(definition!.isFullScreen, isTrue);
    });

    test('guardian_switch の持続時間は4秒である', () {
      final catalog = EffectCatalog.defaultCatalog();
      final definition = catalog.lookup('guardian_switch');
      expect(definition!.duration.inSeconds, 4);
    });
  });
}
