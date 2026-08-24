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
    registerFallbackValue(
      const AndroidNotificationDetails(
        'channel',
        'name',
        channelDescription: 'description',
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

  setUp(() async {
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
    when(() => android.createNotificationChannel(any()))
        .thenAnswer((_) async {});

    // サービスが await するメソッドのデフォルト実装（検証対象は個別に verify）
    when(() => plugin.cancel(any())).thenAnswer((_) async {});
    when(() => plugin.show(any(), any(), any(), any())).thenAnswer((_) async {});
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
        )).thenAnswer((_) async {});

    service = NotificationService(plugin: plugin);
  });

  group('設定の永続化（shared_preferences）', () {
    test('デフォルトでは有効・21時0分のリマインド時刻が返る', () async {
      expect(await service.isEnabled(), true);
      expect(await service.getReminderHour(), 21);
      expect(await service.getReminderMinute(), 0);
    });

    test('saveSettings で保存した設定を再読込できる', () async {
      await service.saveSettings(enabled: false, hour: 20, minute: 30);

      expect(await service.isEnabled(), false);
      expect(await service.getReminderHour(), 20);
      expect(await service.getReminderMinute(), 30);
    });

    test('saveSettings を再度呼ぶと上書きされる', () async {
      await service.saveSettings(enabled: true, hour: 7, minute: 15);
      await service.saveSettings(enabled: false, hour: 23, minute: 45);

      expect(await service.isEnabled(), false);
      expect(await service.getReminderHour(), 23);
      expect(await service.getReminderMinute(), 45);
    });
  });

  group('デイリー記帳リマインドのスケジュール', () {
    test('有効時は zonedSchedule がデイリー繰り返しで呼ばれる', () async {
      await service.saveSettings(enabled: true, hour: 21, minute: 0);

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
          )).called(1);
    });

    test('無効時はリマインドがキャンセルされ zonedSchedule は呼ばれない', () async {
      await service.saveSettings(enabled: false, hour: 21, minute: 0);

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
          ));
    });
  });

  group('予算超過アラート通知', () {
    test('sendBudgetAlert が予算超過IDで show を呼ぶ', () async {
      await service.sendBudgetAlert('今月の予算を超えました');

      verify(() => plugin.show(
            NotificationService.budgetAlertId,
            any(),
            any(),
            any(),
          )).called(1);
    });
  });

  group('テスト通知', () {
    test('sendTestNotification がテストIDで show を呼ぶ', () async {
      await service.sendTestNotification();

      verify(() => plugin.show(
            NotificationService.testNotificationId,
            any(),
            any(),
            any(),
          )).called(1);
    });
  });

  group('cancelAll', () {
    test('全通知IDがキャンセルされる', () async {
      await service.cancelAll();

      verify(() => plugin.cancel(NotificationService.dailyReminderId))
          .called(1);
      verify(() => plugin.cancel(NotificationService.budgetAlertId)).called(1);
      verify(() => plugin.cancel(NotificationService.testNotificationId))
          .called(1);
    });
  });

  group('nextInstanceOfTime', () {
    test('常に未来の時刻を返す', () {
      final result = service.nextInstanceOfTime(12, 0);
      final now = tz.TZDateTime.now(tz.local);
      expect(result.isAfter(now), true,
          reason: 'nextInstanceOfTime は常に未来の時刻を返すこと');
    });

    test('過ぎた時刻なら翌日の同じ時刻を返す', () {
      // 現在時刻から1分前をターゲットにする → 必ず翌日が返る
      final past = tz.TZDateTime.now(tz.local)
          .subtract(const Duration(minutes: 1));
      final result = service.nextInstanceOfTime(past.hour, past.minute);

      final expected = tz.TZDateTime(
        tz.local,
        tz.TZDateTime.now(tz.local).year,
        tz.TZDateTime.now(tz.local).month,
        tz.TZDateTime.now(tz.local).day,
        past.hour,
        past.minute,
      ).add(const Duration(days: 1));

      expect(result.hour, past.hour);
      expect(result.minute, past.minute);
      expect(result.day, expected.day);
      expect(result.month, expected.month);
      expect(result.year, expected.year);
    });
  });

  group('initialize', () {
    test('プラグイン初期化と通知チャンネル作成が行われる', () async {
      when(() => plugin.initialize(any(), onDidReceiveNotificationResponse: any(named: 'onDidReceiveNotificationResponse')))
          .thenAnswer((_) async => true);
      when(() => android.createNotificationChannel(any()))
          .thenAnswer((_) async {});

      await service.initialize();

      verify(() => plugin.initialize(
            any(),
            onDidReceiveNotificationResponse:
                any(named: 'onDidReceiveNotificationResponse'),
          )).called(1);
      // リマインド・予算超過・テストの3チャンネル
      verify(() => android.createNotificationChannel(any())).called(3);
    });
  });
}
