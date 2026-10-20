import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kozuchi/features/quiet_hours/data/quiet_hours_repository.dart';
import 'package:kozuchi/features/quiet_hours/domain/quiet_hours_policy.dart';
import 'package:kozuchi/features/quiet_hours/domain/quiet_hours_settings.dart';

/// 静穏時間リポジトリの試練（InMemory / Noop / SharedPreferences）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final custom = QuietHoursSettings(
    enabled: true,
    startHour: 23,
    startMinute: 30,
    endHour: 6,
    endMinute: 45,
    policy: QuietHoursPolicy.skip,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('InMemoryQuietHoursRepository', () {
    test('未保存なら defaults', () async {
      expect(
        await InMemoryQuietHoursRepository().load(),
        QuietHoursSettings.defaults(),
      );
    });

    test('保存した設定を復元できる', () async {
      final repo = InMemoryQuietHoursRepository();
      await repo.save(custom);
      expect(await repo.load(), custom);
      expect(repo.stored, custom);
    });
  });

  group('NoopQuietHoursRepository', () {
    test('常に defaults を返し保存を無視する', () async {
      final repo = const NoopQuietHoursRepository();
      await repo.save(custom);
      expect(await repo.load(), QuietHoursSettings.defaults());
    });
  });

  group('SharedPreferencesQuietHoursRepository', () {
    test('保存がリポジトリ到達し、別インスタンスで復元できる', () async {
      const repo = SharedPreferencesQuietHoursRepository();
      await repo.save(custom);

      const another = SharedPreferencesQuietHoursRepository();
      expect(await another.load(), custom);

      final prefs = await SharedPreferences.getInstance();
      final raw =
          prefs.getString(SharedPreferencesQuietHoursRepository.storageKey);
      expect(raw, isNotNull);
      expect(jsonDecode(raw!), isA<Map<String, dynamic>>());
    });

    test('保存キーは quiet_hours_settings_v1', () {
      expect(
        SharedPreferencesQuietHoursRepository.storageKey,
        'quiet_hours_settings_v1',
      );
    });

    test('未保存なら defaults', () async {
      expect(
        await const SharedPreferencesQuietHoursRepository().load(),
        QuietHoursSettings.defaults(),
      );
    });

    test('破損JSONなら defaults', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        SharedPreferencesQuietHoursRepository.storageKey: '{not json',
      });
      expect(
        await const SharedPreferencesQuietHoursRepository().load(),
        QuietHoursSettings.defaults(),
      );
    });

    test('JSONだが値が不正なら defaults', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        SharedPreferencesQuietHoursRepository.storageKey:
            jsonEncode(<String, Object>{
          'enabled': true,
          'startHour': 30,
          'startMinute': 0,
          'endHour': 7,
          'endMinute': 0,
          'policy': 'defer',
        }),
      });
      expect(
        await const SharedPreferencesQuietHoursRepository().load(),
        QuietHoursSettings.defaults(),
      );
    });

    test('上書き保存が反映される', () async {
      const repo = SharedPreferencesQuietHoursRepository();
      await repo.save(custom);
      await repo.save(QuietHoursSettings.defaults());
      expect(await repo.load(), QuietHoursSettings.defaults());
    });
  });

  group('QuietHoursRepositoryGuard', () {
    test('静穏内(defer)は翌朝へずらす', () async {
      final repo = InMemoryQuietHoursRepository();
      await repo.save(
        QuietHoursSettings.defaults().copyWith(enabled: true),
      );
      final guard = QuietHoursRepositoryGuard(repo);

      final adjusted = await guard.adjust(DateTime(2026, 10, 21, 23, 30));
      expect(adjusted, DateTime(2026, 10, 22, 7, 0));
    });

    test('静穏内(skip)は null', () async {
      final repo = InMemoryQuietHoursRepository();
      await repo.save(
        QuietHoursSettings.defaults()
            .copyWith(enabled: true, policy: QuietHoursPolicy.skip),
      );
      final guard = QuietHoursRepositoryGuard(repo);

      expect(await guard.adjust(DateTime(2026, 10, 21, 23, 30)), isNull);
    });

    test('静穏外は素通し', () async {
      final repo = InMemoryQuietHoursRepository();
      await repo.save(QuietHoursSettings.defaults().copyWith(enabled: true));
      final guard = QuietHoursRepositoryGuard(repo);

      final scheduled = DateTime(2026, 10, 21, 12, 0);
      expect(await guard.adjust(scheduled), scheduled);
    });

    test('無効時は素通し', () async {
      final guard = QuietHoursRepositoryGuard(InMemoryQuietHoursRepository());
      final scheduled = DateTime(2026, 10, 21, 23, 30);
      expect(await guard.adjust(scheduled), scheduled);
    });
  });
}
