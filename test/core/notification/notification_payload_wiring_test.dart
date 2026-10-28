import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/core/infrastructure/notification_service.dart';
import 'package:kozuchi/core/notification/notification_route_resolver.dart';
import 'package:kozuchi/features/notification_settings/data/notification_settings_repository.dart';
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
  late List<ResolvedNotificationRoute> delivered;
  late DidReceiveNotificationResponseCallback? tapCallback;
  late Future<NotificationAppLaunchDetails?> launchDetails;

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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    delivered = <ResolvedNotificationRoute>[];
    tapCallback = null;
    launchDetails = Future<NotificationAppLaunchDetails?>.value(null);

    plugin = _MockPlugin();
    android = _MockAndroidPlugin();

    when(() => plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()).thenReturn(android);
    when(() => android.canScheduleExactNotifications())
        .thenAnswer((_) async => true);
    when(() => android.createNotificationChannel(any()))
        .thenAnswer((_) async {});
    when(() => plugin.cancel(any())).thenAnswer((_) async {});
    when(() => plugin.initialize(
          any(),
          onDidReceiveNotificationResponse: any(
            named: 'onDidReceiveNotificationResponse',
          ),
        )).thenAnswer((invocation) async {
      tapCallback = invocation.namedArguments[#onDidReceiveNotificationResponse]
          as DidReceiveNotificationResponseCallback?;
      return true;
    });
    when(() => plugin.getNotificationAppLaunchDetails())
        .thenAnswer((_) => launchDetails);
    // payload を含む完全な形で stub する（mocktail は named 引数の鍵集合を比較する）。
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
    when(() => plugin.show(
          any(),
          any(),
          any(),
          any(),
          payload: any(named: 'payload'),
        )).thenAnswer((_) async {});
  });

  NotificationService buildService() => NotificationService(
        plugin: plugin,
        settingsRepository: InMemoryNotificationSettingsRepository()
          ..stored = null,
        onRouteSelected: delivered.add,
      );

  NotificationService buildServiceWithoutCallback() => NotificationService(
        plugin: plugin,
        settingsRepository: InMemoryNotificationSettingsRepository()
          ..stored = null,
      );

  NotificationResponse responseWith(String? payload) => NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        id: NotificationService.dailyReminderId,
        payload: payload,
      );

  void fireTap(String? payload) {
    tapCallback!(responseWith(payload));
  }

  String captureScheduledPayload() {
    final captured = verify(() => plugin.zonedSchedule(
          any(),
          any(),
          any(),
          any(),
          any(),
          androidScheduleMode: any(named: 'androidScheduleMode'),
          uiLocalNotificationDateInterpretation:
              any(named: 'uiLocalNotificationDateInterpretation'),
          matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
          payload: captureAny(named: 'payload'),
        )).captured;
    return captured.single as String;
  }

  String captureShownPayload() {
    final captured = verify(() => plugin.show(
          any(),
          any(),
          any(),
          any(),
          payload: captureAny(named: 'payload'),
        )).captured;
    return captured.single as String;
  }

  group('payload 付与', () {
    test('デイリー記帳リマインドは transactions 経路の payload を持つ', () async {
      final service = buildService();

      await service.scheduleDailyReminder();

      final payload = captureScheduledPayload();
      final resolved = NotificationRouteResolver.resolve(
        payload,
        allowedRoutes: NotificationRoutes.all,
      );
      expect(resolved?.route, NotificationRoutes.transactions);
    });

    test('予算超過アラートは budget 経路の payload を持つ', () async {
      final service = buildService();

      await service.sendBudgetAlert('予算を超えました');

      final resolved = NotificationRouteResolver.resolve(
        captureShownPayload(),
        allowedRoutes: NotificationRoutes.all,
      );
      expect(resolved?.route, NotificationRoutes.budget);
    });

    test('テスト通知は home 経路の payload を持つ', () async {
      final service = buildService();

      await service.sendTestNotification();

      final resolved = NotificationRouteResolver.resolve(
        captureShownPayload(),
        allowedRoutes: NotificationRoutes.all,
      );
      expect(resolved?.route, NotificationRoutes.home);
    });

    test('付与される payload はすべて allowedRoutes で解決できる', () async {
      final service = buildService();

      await service.scheduleDailyReminder();
      final scheduled = captureScheduledPayload();
      await service.sendBudgetAlert('超過');
      await service.sendTestNotification();
      final shown = verify(() => plugin.show(
            any(),
            any(),
            any(),
            any(),
            payload: captureAny(named: 'payload'),
          )).captured.cast<String>();

      expect(shown, hasLength(2));
      final budget = shown[0];
      final testPayload = shown[1];

      for (final payload in <String>[scheduled, budget, testPayload]) {
        final resolved = NotificationRouteResolver.resolve(
          payload,
          allowedRoutes: NotificationRoutes.all,
        );
        expect(resolved, isNotNull, reason: 'payload=$payload');
      }
      expect(scheduled, isNot(equals(budget)));
      expect(budget, isNot(equals(testPayload)));
    });
  });

  group('タップ経路', () {
    test('既知 payload のタップで onRouteSelected に解決結果が届く', () async {
      final service = buildService();
      await service.initialize();

      fireTap(NotificationRouteResolver.buildPayload(
        NotificationRoutes.budget,
        id: '2026-10',
      ));

      expect(delivered, hasLength(1));
      expect(delivered.single.route, NotificationRoutes.budget);
      expect(delivered.single.id, '2026-10');
    });

    test('未知 route の payload では通知しない', () async {
      final service = buildService();
      await service.initialize();

      fireTap(NotificationRouteResolver.buildPayload('settings'));

      expect(delivered, isEmpty);
    });

    test('payload なしのタップでは通知しない', () async {
      final service = buildService();
      await service.initialize();

      fireTap(null);

      expect(delivered, isEmpty);
    });

    test('壊れた payload のタップでも例外を投げない', () async {
      final service = buildService();
      await service.initialize();

      expect(() => fireTap('{"route":'), returnsNormally);
      expect(delivered, isEmpty);
    });

    test('コールバック未注入なら pendingRoute に残り1度だけ取り出せる', () async {
      final service = buildServiceWithoutCallback();
      await service.initialize();

      fireTap(NotificationRouteResolver.buildPayload(NotificationRoutes.home));

      expect(service.pendingRoute?.route, NotificationRoutes.home);
      expect(service.consumePendingRoute()?.route, NotificationRoutes.home);
      expect(service.consumePendingRoute(), isNull);
      expect(service.pendingRoute, isNull);
    });

    test('コールバック注入時は配信後に pendingRoute を残さない', () async {
      final service = buildService();
      await service.initialize();

      fireTap(
        NotificationRouteResolver.buildPayload(NotificationRoutes.transactions),
      );

      expect(delivered, hasLength(1));
      expect(service.pendingRoute, isNull);
      expect(service.consumePendingRoute(), isNull);
    });
  });

  group('起動経由（getNotificationAppLaunchDetails）', () {
    test('通知起動なら同じ入口で onRouteSelected に届く', () async {
      launchDetails = Future<NotificationAppLaunchDetails?>.value(
        NotificationAppLaunchDetails(
          true,
          notificationResponse: responseWith(
            NotificationRouteResolver.buildPayload(NotificationRoutes.budget),
          ),
        ),
      );
      final service = buildService();

      await service.initialize();

      expect(delivered, hasLength(1));
      expect(delivered.single.route, NotificationRoutes.budget);
    });

    test('通知起動でなければ何も届かない', () async {
      launchDetails = Future<NotificationAppLaunchDetails?>.value(
        const NotificationAppLaunchDetails(false),
      );
      final service = buildService();

      await service.initialize();

      expect(delivered, isEmpty);
      expect(service.pendingRoute, isNull);
    });

    test('起動詳細が例外でも initialize は完了する', () async {
      when(() => plugin.getNotificationAppLaunchDetails()).thenAnswer(
        (_) async => throw StateError('launch details unavailable'),
      );
      final service = buildService();

      await service.initialize();

      expect(delivered, isEmpty);
      verify(() => android.createNotificationChannel(any())).called(3);
    });
  });
}
