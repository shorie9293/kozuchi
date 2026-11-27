import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/core/infrastructure/notification_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class _MockPlugin extends Mock implements FlutterLocalNotificationsPlugin {}

class _MockAndroidPlugin extends Mock
    implements AndroidFlutterLocalNotificationsPlugin {}

/// 正確なアラーム権限の常時宣言（USE_EXACT_ALARM）撤去後の
/// exact/inexact 切替を検証する試練。
///
/// シーム [NotificationService.exactAlarmAllowed] を注入し、実際の
/// `zonedSchedule` 呼び出しに渡る `androidScheduleMode` を観測する。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockPlugin plugin;
  late _MockAndroidPlugin android;

  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));

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
      const AndroidNotificationDetails(
        'channel',
        'name',
        channelDescription: 'description',
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

    when(() => plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>())
        .thenReturn(android);
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
  });

  void verifyScheduleMode(AndroidScheduleMode mode) {
    verify(() => plugin.zonedSchedule(
          NotificationService.dailyReminderId,
          any(),
          any(),
          any(),
          any(),
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: any(named: 'payload'),
        )).called(1);
  }

  test('シーム=false なら inexactAllowWhileIdle でスケジュールする', () async {
    final service = NotificationService(
      plugin: plugin,
      exactAlarmAllowed: () async => false,
    );

    await service.scheduleDailyReminder();

    verifyScheduleMode(AndroidScheduleMode.inexactAllowWhileIdle);
    // シームが優先され、プラグイン照会は行われない
    verifyNever(() => android.canScheduleExactNotifications());
  });

  test('シーム=true なら exactAllowWhileIdle でスケジュールする', () async {
    final service = NotificationService(
      plugin: plugin,
      exactAlarmAllowed: () async => true,
    );

    await service.scheduleDailyReminder();

    verifyScheduleMode(AndroidScheduleMode.exactAllowWhileIdle);
    verifyNever(() => android.canScheduleExactNotifications());
  });

  test('シーム未注入なら従来どおりプラグイン照会にフォールバックする', () async {
    when(() => android.canScheduleExactNotifications())
        .thenAnswer((_) async => false);
    final service = NotificationService(plugin: plugin);

    await service.scheduleDailyReminder();

    verifyScheduleMode(AndroidScheduleMode.inexactAllowWhileIdle);
    verify(() => android.canScheduleExactNotifications()).called(1);
  });
}
