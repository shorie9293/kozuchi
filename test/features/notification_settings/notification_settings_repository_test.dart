import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kozuchi/features/notification_settings/data/notification_settings_repository.dart';
import 'package:kozuchi/features/notification_settings/domain/notification_settings.dart';

void main() {
  group('InMemoryNotificationSettingsRepository', () {
    test('未保存時は既定値を返す', () async {
      final repo = InMemoryNotificationSettingsRepository();
      expect(await repo.load(), NotificationSettings.defaults());
    });

    test('save→load の往復で同じ設定が返る', () async {
      final repo = InMemoryNotificationSettingsRepository();
      final s = NotificationSettings(
        enabled: false,
        hour: 7,
        minute: 30,
        enabledKinds: {NotificationKind.dailyReminder},
      );
      await repo.save(s);
      expect(await repo.load(), s);
      expect(repo.stored, s);
    });

    test('save の上書きが反映される', () async {
      final repo = InMemoryNotificationSettingsRepository();
      await repo.save(NotificationSettings.defaults());
      final s2 = NotificationSettings.defaults().copyWith(hour: 6);
      await repo.save(s2);
      expect(await repo.load(), s2);
    });
  });

  group('NoopNotificationSettingsRepository', () {
    test('load は常に既定値、save は無視される', () async {
      final repo = const NoopNotificationSettingsRepository();
      final s = NotificationSettings.defaults().copyWith(hour: 3);
      await repo.save(s);
      expect(await repo.load(), NotificationSettings.defaults());
    });
  });

  group('SharedPreferencesNotificationSettingsRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('storageKey は notification_settings_v1', () {
      expect(
        SharedPreferencesNotificationSettingsRepository.storageKey,
        'notification_settings_v1',
      );
    });

    test('未保存時は defaults を返す', () async {
      final repo = const SharedPreferencesNotificationSettingsRepository();
      expect(await repo.load(), NotificationSettings.defaults());
    });

    test('save→load の往復', () async {
      final repo = const SharedPreferencesNotificationSettingsRepository();
      final s = NotificationSettings(
        enabled: false,
        hour: 6,
        minute: 15,
        enabledKinds: {
          NotificationKind.dailyReminder,
          NotificationKind.budgetAlert,
        },
      );
      await repo.save(s);
      expect(await repo.load(), s);
    });

    test('save は JSON 文字列を指定キーに書き込む', () async {
      final repo = const SharedPreferencesNotificationSettingsRepository();
      final s = NotificationSettings.defaults().copyWith(hour: 8);
      await repo.save(s);

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(
        SharedPreferencesNotificationSettingsRepository.storageKey,
      );
      expect(raw, isNotNull);
      expect(raw, contains('"hour":8'));
    });

    test('破損JSON は defaults を返す（例外を投げない）', () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesNotificationSettingsRepository.storageKey: '{{{not json',
      });
      final repo = const SharedPreferencesNotificationSettingsRepository();
      expect(await repo.load(), NotificationSettings.defaults());
    });

    test('型不正（JSON配列）は defaults を返す', () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesNotificationSettingsRepository.storageKey: '[1,2,3]',
      });
      final repo = const SharedPreferencesNotificationSettingsRepository();
      expect(await repo.load(), NotificationSettings.defaults());
    });

    test('tolerant な JSON は fromJson の規則に従う', () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesNotificationSettingsRepository.storageKey:
            '{"hour":25,"enabledKinds":["daily_reminder","nope"]}',
      });
      final repo = const SharedPreferencesNotificationSettingsRepository();
      final loaded = await repo.load();
      expect(loaded.hour, 21);
      expect(
        loaded.enabledKinds,
        {NotificationKind.dailyReminder},
      );
    });
  });
}
