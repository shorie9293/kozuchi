import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/core/theme/text_scale_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TextScaleSetting', () {
    test('presetsは3段階・通常は1.0倍を含む', () {
      expect(TextScaleSetting.presets.length, 3);
      expect(TextScaleSetting.presets[0].scale, 0.9);
      expect(TextScaleSetting.presets[1].scale, 1.0);
      expect(TextScaleSetting.presets[2].scale, 1.25);
      expect(TextScaleSetting.presets[1].label, '通常');
    });

    test('isAllowed: 許可値はtrue・範囲外はfalse', () {
      expect(TextScaleSetting.isAllowed(1.0), isTrue);
      expect(TextScaleSetting.isAllowed(0.9), isTrue);
      expect(TextScaleSetting.isAllowed(1.25), isTrue);
      expect(TextScaleSetting.isAllowed(1.1), isFalse);
      expect(TextScaleSetting.isAllowed(0.5), isFalse);
      expect(TextScaleSetting.isAllowed(2.0), isFalse);
    });

    test('fromScale: 未保存null/不正値はnull・許可値は対応設定', () {
      expect(TextScaleSetting.fromScale(null), isNull);
      expect(TextScaleSetting.fromScale(1.1), isNull);
      expect(TextScaleSetting.fromScale(1.25)?.label, '大');
      expect(TextScaleSetting.fromScale(0.9)?.label, '小');
    });

    test('normalized: 未保存/不正値は1.0へ正規化', () {
      expect(TextScaleSetting.normalized(null), 1.0);
      expect(TextScaleSetting.normalized(1.1), 1.0);
      expect(TextScaleSetting.normalized(1.25), 1.25);
      expect(TextScaleSetting.normalized(0.9), 0.9);
    });
  });

  group('TextScaleRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('未保存時はloadScaleがnullを返す', () async {
      final repo = const TextScaleRepository();
      expect(await repo.loadScale(), isNull);
    });

    test('saveScale→loadScaleの往復で保存値を復元する', () async {
      final repo = const TextScaleRepository();
      await repo.saveScale(1.25);
      expect(await repo.loadScale(), 1.25);
      await repo.saveScale(0.9);
      expect(await repo.loadScale(), 0.9);
    });

    test('許可外の倍率の保存はArgumentError', () async {
      final repo = const TextScaleRepository();
      expect(() => repo.saveScale(1.1), throwsArgumentError);
      expect(() => repo.saveScale(0.0), throwsArgumentError);
    });

    test('破損値（許可外の保存値）はloadScaleでnullに読み飛ばす', () async {
      SharedPreferences.setMockInitialValues({'kozuchi_text_scale': 3.7});
      final repo = const TextScaleRepository();
      expect(await repo.loadScale(), isNull);
    });
  });
}