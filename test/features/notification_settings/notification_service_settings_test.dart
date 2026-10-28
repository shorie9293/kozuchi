import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/core/infrastructure/notification_service.dart';
import 'package:kozuchi/features/notification_settings/data/notification_settings_repository.dart';
import 'package:kozuchi/features/notification_settings/domain/notification_settings.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class _MockPlugin extends Mock implements FlutterLocalNotificationsPlugin {}

class _MockAndroidPlugin extends Mock
    implements AndroidFlutterLocalNotificationsPlugin {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockPlugin plugin;
  late _MockAndroidPlugin android;
  late InMemoryNotificationSettingsRepository repo;
  late NotificationService service;

  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));

    registerFallbackValue(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    registerFallbackValue(
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'channel',
          'name',
          channelDescription: 'description',
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
    registerFallbackValue(
      const AndroidNotificationChannel(
        'channel',
        'name',
        description: 'description',
      ),
    );
    registerFallbackValue(tz.TZDateTime(tz.local, 2026, 1, 1));
    registerFallbackValue(AndroidScheduleMode.exactAllowWhileIdle);
    registerFallbackValue(UILocalNotificationDateInterpretation.absoluteTime);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));

    plugin = _MockPlugin();
    android = _MockAndroidPlugin();
    repo = InMemoryNotificationSettingsRepository();

    when(() => plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>())
        .thenReturn(android);
    when(() => android.canScheduleExactNotifications())
        .thenAnswer((_) async => true);

    when(() => plugin.cancel(any())).thenAnswer((_) async {});
    when(() => plugin.show(
          any(),
          any(),
          any(),
          any(),
          payload: any(named: 'payload'),
        )).thenAnswer((_) async {});
    when(() => plugin.zonedSchedule(
          any(),
          any(),
          any(),
          any(),
          any(),
          androidScheduleMode: any(named: 'androidScheduleMode'),
          uiLocalNotificationDateInterpretation:
              any(named: 'uiLocalNotificationDateInterpretation'),
          matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
          payload: any(named: 'payload'),
        )).thenAnswer((_) async {});

    service = NotificationService(
      plugin: plugin,
      settingsRepository: repo,
    );
  });

  group('scheduleDailyReminder（種類別OFF含む）', () {
    test('マスターOFF → cancel のみ・zonedSchedule は呼ばれない', () async {
      repo.stored = NotificationSettings.defaults().copyWith(enabled: false);

      await service.scheduleDailyReminder();

      verify(() => plugin.cancel(NotificationService.dailyReminderId))
          .called(1);
      verifyNever(() => plugin.zonedSchedule(
            any(),
            any(),
            any(),
            any(),
            any(),
            androidScheduleMode: any(named: 'androidScheduleMode'),
            uiLocalNotificationDateInterpretation:
                any(named: 'uiLocalNotificationDateInterpretation'),
            matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
            payload: any(named: 'payload'),
          ));
    });

    test('dailyReminder 種類OFF → cancel のみ・zonedSchedule は呼ばれない',
        () async {
      repo.stored = NotificationSettings.defaults().toggleKind(
            NotificationKind.dailyReminder,
          );

      await service.scheduleDailyReminder();

      verify(() => plugin.cancel(NotificationService.dailyReminderId))
          .called(1);
      verifyNever(() => plugin.zonedSchedule(
            any(),
            any(),
            any(),
            any(),
            any(),
            androidScheduleMode: any(named: 'androidScheduleMode'),
            uiLocalNotificationDateInterpretation:
                any(named: 'uiLocalNotificationDateInterpretation'),
            matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
            payload: any(named: 'payload'),
          ));
    });

    test('保存した時刻 hour=7 minute=15 が zonedSchedule に渡される', () async {
      repo.stored = NotificationSettings.defaults().copyWith(hour: 7, minute: 15);

      tz.TZDateTime? captured;
      when(() => plugin.zonedSchedule(
            any(),
            any(),
            any(),
            any(),
            any(),
            androidScheduleMode: any(named: 'androidScheduleMode'),
            uiLocalNotificationDateInterpretation:
                any(named: 'uiLocalNotificationDateInterpretation'),
            matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
            payload: any(named: 'payload'),
          )).thenAnswer((inv) async {
        captured = inv.positionalArguments[3] as tz.TZDateTime;
      });

      await service.scheduleDailyReminder();

      verify(() => plugin.zonedSchedule(
            any(),
            any(),
            any(),
            any(),
            any(),
            androidScheduleMode: any(named: 'androidScheduleMode'),
            uiLocalNotificationDateInterpretation:
                any(named: 'uiLocalNotificationDateInterpretation'),
            matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
            payload: any(named: 'payload'),
          )).called(1);
      expect(captured!.hour, 7);
      expect(captured!.minute, 15);
    });
  });

  group('sendBudgetAlert（種類別OFF）', () {
    test('budgetAlert 種類OFF → show は呼ばれない', () async {
      repo.stored = NotificationSettings.defaults().toggleKind(
            NotificationKind.budgetAlert,
          );

      await service.sendBudgetAlert('予算超過');

      verifyNever(() => plugin.show(
            any(),
            any(),
            any(),
            any(),
            payload: any(named: 'payload'),
          ));
    });

    test('budgetAlert 種類ON（既定）→ show が呼ばれる', () async {
      repo.stored = NotificationSettings.defaults();

      await service.sendBudgetAlert('予算超過');

      verify(() => plugin.show(
            NotificationService.budgetAlertId,
            any(),
            any(),
            any(),
            payload: any(named: 'payload'),
          )).called(1);
    });
  });

  group('saveSettings と読み出し', () {
    test('saveSettings → リポジトリへ保存され、読み出しも一致する', () async {
      await service.saveSettings(enabled: false, hour: 20, minute: 30);

      expect(repo.stored, isNotNull);
      expect(repo.stored!.enabled, false);
      expect(repo.stored!.hour, 20);
      expect(repo.stored!.minute, 30);
      expect(await service.isEnabled(), false);
      expect(await service.getReminderHour(), 20);
      expect(await service.getReminderMinute(), 30);
    });
  });

  group('loadSettings の移行・優先', () {
    test('後方互換マイグレーション: 旧キーのみ → 旧値を採用し新キーへ書き戻す', () async {
      SharedPreferences.setMockInitialValues({
        'notification_enabled': false,
        'notification_hour': 6,
        'notification_minute': 45,
      });

      final s = await service.loadSettings();

      expect(s.enabled, false);
      expect(s.hour, 6);
      expect(s.minute, 45);
      // 初回のみの移行で新キーへ書き戻されている
      expect(repo.stored, isNotNull);
      expect(repo.stored!.enabled, false);
      expect(repo.stored!.hour, 6);
      expect(repo.stored!.minute, 45);
    });

    test('新キー優先: 旧キーと新キー両方があれば新キーを採用する', () async {
      // 「新キー保存済み」の状態を模擬（prefs の文字列と InMemory.stored）
      final saved = NotificationSettings.defaults().copyWith(
        hour: 9,
        enabled: false,
      );
      repo.stored = saved;
      SharedPreferences.setMockInitialValues({
        'notification_enabled': true,
        'notification_hour': 5,
        'notification_minute': 0,
        SharedPreferencesNotificationSettingsRepository.storageKey:
            jsonEncode(saved.toJson()),
      });

      final s = await service.loadSettings();

      expect(s.enabled, false);
      expect(s.hour, 9);
      expect(s.minute, 0);
    });

    test('移行済みなら再読込時も新キーの値を使う', () async {
      SharedPreferences.setMockInitialValues({
        'notification_enabled': false,
        'notification_hour': 6,
        'notification_minute': 45,
      });
      await service.loadSettings();

      // 新キーへ移行済みなので、旧キーの値が変わっても新キーが優先される
      final saved =
          NotificationSettings.defaults().copyWith(hour: 12);
      repo.stored = saved;
      SharedPreferences.setMockInitialValues({
        'notification_enabled': true,
        'notification_hour': 23,
        'notification_minute': 59,
        SharedPreferencesNotificationSettingsRepository.storageKey:
            jsonEncode(saved.toJson()),
      });

      final s = await service.loadSettings();
      expect(s.hour, 12);
      expect(s.enabled, true);
    });
  });

  group('sendTestNotification', () {
    test('マスターOFFでも動作確認用に show が呼ばれる', () async {
      repo.stored = NotificationSettings.defaults().copyWith(enabled: false);

      await service.sendTestNotification();

      verify(() => plugin.show(
            NotificationService.testNotificationId,
            any(),
            any(),
            any(),
            payload: any(named: 'payload'),
          )).called(1);
    });
  });
}
