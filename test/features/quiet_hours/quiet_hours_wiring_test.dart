import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:kozuchi/core/infrastructure/notification_service.dart';
import 'package:kozuchi/features/notification_settings/data/notification_settings_repository.dart';
import 'package:kozuchi/features/notification_settings/domain/notification_settings.dart';
import 'package:kozuchi/features/notification_settings/presentation/notification_settings_app_keys.dart';
import 'package:kozuchi/features/notification_settings/presentation/notification_settings_screen.dart';
import 'package:kozuchi/features/quiet_hours/domain/quiet_hours_service.dart';

class _MockPlugin extends Mock implements FlutterLocalNotificationsPlugin {}

class _MockAndroidPlugin extends Mock
    implements AndroidFlutterLocalNotificationsPlugin {}

/// 固定の調整結果を返す偽ガード。
class _FakeGuard implements QuietHoursGuard {
  _FakeGuard(this.result);
  final DateTime? result;
  int calls = 0;

  @override
  Future<DateTime?> adjust(DateTime scheduled) async {
    calls++;
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockPlugin plugin;
  late _MockAndroidPlugin android;
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
    registerFallbackValue(tz.TZDateTime(tz.local, 2026, 1, 1));
    registerFallbackValue(AndroidScheduleMode.exactAllowWhileIdle);
    registerFallbackValue(UILocalNotificationDateInterpretation.absoluteTime);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    plugin = _MockPlugin();
    android = _MockAndroidPlugin();

    when(() => plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()).thenReturn(android);
    when(() => android.canScheduleExactNotifications())
        .thenAnswer((_) async => true);
    when(() => plugin.cancel(any())).thenAnswer((_) async {});
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
      settingsRepository: InMemoryNotificationSettingsRepository()
        ..stored = NotificationSettings.defaults(),
    );
  });

  group('guard null は従来挙動（後方互換）', () {
    test('guard 未指定で zonedSchedule が従来通り1回呼ばれる', () async {
      await service.scheduleDailyReminder();

      verify(() => plugin.zonedSchedule(
            NotificationService.dailyReminderId,
            any(),
            any(),
            any(),
            any(),
            uiLocalNotificationDateInterpretation:
                any(named: 'uiLocalNotificationDateInterpretation'),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.time,
            payload: any(named: 'payload'),
          )).called(1);
    });

    test('guard: null を明示しても従来通り', () async {
      await service.scheduleDailyReminder(guard: null);

      verify(() => plugin.zonedSchedule(
            NotificationService.dailyReminderId,
            any(),
            any(),
            any(),
            any(),
            uiLocalNotificationDateInterpretation:
                any(named: 'uiLocalNotificationDateInterpretation'),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.time,
            payload: any(named: 'payload'),
          )).called(1);
      verifyNever(() => plugin.cancel(NotificationService.dailyReminderId));
    });
  });

  group('guard 非null は抑止・繰り延べを反映する', () {
    test('adjust が null なら schedule せずキャンセルする', () async {
      final guard = _FakeGuard(null);

      await service.scheduleDailyReminder(guard: guard);

      expect(guard.calls, 1);
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
          ));
      verify(() => plugin.cancel(NotificationService.dailyReminderId))
          .called(1);
    });

    test('adjust が返した時刻で schedule する', () async {
      final target = tz.TZDateTime(tz.local, 2026, 10, 22, 7, 0);
      final guard = _FakeGuard(target);

      await service.scheduleDailyReminder(guard: guard);

      verify(() => plugin.zonedSchedule(
            NotificationService.dailyReminderId,
            any(),
            any(),
            target,
            any(),
            uiLocalNotificationDateInterpretation:
                any(named: 'uiLocalNotificationDateInterpretation'),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.time,
            payload: any(named: 'payload'),
          )).called(1);
    });
  });

  group('通知設定画面からの静穏時間への導線', () {
    testWidgets('quietHoursScreenBuilder 未指定なら導線は出ない', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NotificationSettingsScreen(
            repository: InMemoryNotificationSettingsRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(NotificationSettingsAppKeys.quietHoursEntry),
        findsNothing,
      );
    });

    testWidgets('quietHoursScreenBuilder 指定時はタップで遷移する', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NotificationSettingsScreen(
            repository: InMemoryNotificationSettingsRepository(),
            quietHoursScreenBuilder: (_) => const Scaffold(
              body: Text('静穏時間の画面'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final entry = find.byKey(NotificationSettingsAppKeys.quietHoursEntry);
      expect(entry, findsOneWidget);

      await tester.tap(entry);
      await tester.pumpAndSettle();

      expect(find.text('静穏時間の画面'), findsOneWidget);
    });
  });
}
