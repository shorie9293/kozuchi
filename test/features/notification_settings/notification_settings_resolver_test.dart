import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/notification_settings/domain/notification_settings.dart';
import 'package:kozuchi/features/notification_settings/domain/notification_settings_resolver.dart';

void main() {
  group('LegacyNotificationSettings', () {
    test('isPresent はいずれかの旧キーが存在すれば true', () {
      expect(const LegacyNotificationSettings(enabled: true).isPresent, true);
      expect(const LegacyNotificationSettings(hour: 6).isPresent, true);
      expect(const LegacyNotificationSettings(minute: 45).isPresent, true);
      expect(LegacyNotificationSettings.empty.isPresent, false);
    });

    test('toSettings は欠落時の既定値（enabled=true / 21:00）を採用する', () {
      final s = LegacyNotificationSettings.empty.toSettings();
      expect(s.enabled, true);
      expect(s.hour, 21);
      expect(s.minute, 0);
      expect(s.enabledKinds, NotificationKind.values.toSet());
    });

    test('toSettings は旧値を採用する', () {
      final s = const LegacyNotificationSettings(
        enabled: false,
        hour: 6,
        minute: 45,
      ).toSettings();
      expect(s.enabled, false);
      expect(s.hour, 6);
      expect(s.minute, 45);
    });

    test('toSettings は範囲外の hour/minute を既定値へフォールバックする', () {
      final s = const LegacyNotificationSettings(hour: 99, minute: -1)
          .toSettings();
      expect(s.hour, 21);
      expect(s.minute, 0);
    });
  });

  group('needsMigration', () {
    test('新キーが未保存かつ旧キーが存在する → true', () {
      expect(
        NotificationSettingsResolver.needsMigration(
          hasStoredSettings: false,
          legacy: const LegacyNotificationSettings(enabled: true),
        ),
        true,
      );
    });

    test('新キー保存済み → false', () {
      expect(
        NotificationSettingsResolver.needsMigration(
          hasStoredSettings: true,
          legacy: const LegacyNotificationSettings(enabled: true),
        ),
        false,
      );
    });

    test('旧キーが存在しない → false', () {
      expect(
        NotificationSettingsResolver.needsMigration(
          hasStoredSettings: false,
          legacy: LegacyNotificationSettings.empty,
        ),
        false,
      );
    });
  });

  group('resolve', () {
    test('移行が必要なら旧値から組み立てた設定を返す', () {
      final resolved = NotificationSettingsResolver.resolve(
        stored: NotificationSettings.defaults(),
        hasStoredSettings: false,
        legacy: const LegacyNotificationSettings(
          enabled: false,
          hour: 6,
          minute: 45,
        ),
      );
      expect(resolved.enabled, false);
      expect(resolved.hour, 6);
      expect(resolved.minute, 45);
    });

    test('非移行時は stored をそのまま返す', () {
      final stored = NotificationSettings.defaults().copyWith(hour: 8);
      final resolved = NotificationSettingsResolver.resolve(
        stored: stored,
        hasStoredSettings: true,
        legacy: const LegacyNotificationSettings(enabled: false),
      );
      expect(identical(resolved, stored), true);
      expect(resolved.hour, 8);
    });

    test('旧キーも新キーも無い場合は stored（既定）を返す', () {
      final resolved = NotificationSettingsResolver.resolve(
        stored: NotificationSettings.defaults(),
        hasStoredSettings: false,
        legacy: LegacyNotificationSettings.empty,
      );
      expect(resolved, NotificationSettings.defaults());
    });
  });

  group('isActive', () {
    test('全体OFF → false', () {
      final s = NotificationSettings.defaults().copyWith(enabled: false);
      expect(
        NotificationSettingsResolver.isActive(s, NotificationKind.dailyReminder),
        false,
      );
    });

    test('種類OFF → false', () {
      final s = NotificationSettings.defaults().toggleKind(
            NotificationKind.budgetAlert,
          );
      expect(
        NotificationSettingsResolver.isActive(s, NotificationKind.budgetAlert),
        false,
      );
      expect(
        NotificationSettingsResolver.isActive(s, NotificationKind.dailyReminder),
        true,
      );
    });

    test('全体ONかつ種類ON → true', () {
      final s = NotificationSettings.defaults();
      expect(
        NotificationSettingsResolver.isActive(s, NotificationKind.dailyReminder),
        true,
      );
    });
  });
}
