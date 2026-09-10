import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/features/budget/data/rollover_settings_repository.dart';
import 'package:kozuchi/features/budget/domain/budget_rollover.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RolloverSettingsRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = const RolloverSettingsRepository();
  });

  group('RolloverSettingsRepository', () {
    test('未保存時はデフォルト（無効・上限なし）', () async {
      final settings = await repository.load();
      expect(settings.enabled, isFalse);
      expect(settings.cap, isNull);
    });

    test('save→load 往復で復元される', () async {
      await repository.save(const RolloverSettings(enabled: true, cap: 30000));
      final settings = await repository.load();
      expect(settings.enabled, isTrue);
      expect(settings.cap, 30000);
    });

    test('setEnabled は cap を保持する', () async {
      await repository.save(const RolloverSettings(enabled: false, cap: 30000));
      final updated = await repository.setEnabled(true);
      expect(updated.enabled, isTrue);
      expect(updated.cap, 30000);
    });

    test('setCap で上限を設定できる', () async {
      await repository.setEnabled(true);
      final updated = await repository.setCap(15000);
      expect(updated.cap, 15000);
      expect(updated.enabled, isTrue);
    });

    test('setCap(null) で上限を解除できる', () async {
      await repository.save(const RolloverSettings(enabled: true, cap: 15000));
      final updated = await repository.setCap(null);
      expect(updated.cap, isNull);
      expect((await repository.load()).cap, isNull);
    });

    test('破損データはデフォルトを返す', () async {
      SharedPreferences.setMockInitialValues(
        {'kozuchi_budget_rollover': '{not json'},
      );
      final settings = await repository.load();
      expect(settings.enabled, isFalse);
    });
  });
}
