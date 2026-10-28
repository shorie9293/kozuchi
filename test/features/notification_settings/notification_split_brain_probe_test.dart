import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/core/infrastructure/notification_service.dart';
import 'package:kozuchi/features/notification_settings/data/notification_settings_repository.dart';
import 'package:kozuchi/features/notification_settings/domain/notification_settings.dart';
import 'package:kozuchi/features/notification_settings/presentation/notification_settings_app_keys.dart';
import 'package:kozuchi/features/notification_settings/presentation/notification_settings_screen.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class _MockPlugin extends Mock implements FlutterLocalNotificationsPlugin {}

class _MockAndroidPlugin extends Mock
    implements AndroidFlutterLocalNotificationsPlugin {}

/// 親探針（イシコリドメ）: 通知設定の分裂（split-brain）根治の合成不変条件。
///
/// 子が個別に撃つ「設定の読み書き」と「通知呼出」を**合成**して、
/// 「画面で変えた設定が実際の通知挙動に効く」ことを撃つ。
/// 併せて移行の一回性・種類別ON/OFFの保持を回帰として固定する。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockPlugin plugin;
  late _MockAndroidPlugin android;

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
    plugin = _MockPlugin();
    android = _MockAndroidPlugin();

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
  });

  group('親探針: 設定 → 通知挙動の合成', () {
    testWidgets('画面でマスターOFFにすると、同一リポジトリを見る NotificationService がリマインドをキャンセルする',
        (tester) async {
      final repo = InMemoryNotificationSettingsRepository();
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        MaterialApp(
          home: NotificationSettingsScreen(
            repository: repo,
            onSaved: (_) async {
              await NotificationService(
                plugin: plugin,
                settingsRepository: repo,
              ).scheduleDailyReminder();
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.byKey(NotificationSettingsAppKeys.masterSwitch));
      await tester.pumpAndSettle();

      // 保存がリポジトリへ到達し、通知スケジュールが実際にキャンセルされた
      expect(repo.stored?.enabled, false);
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

    test('画面が保存した 7:15 が、サービス経由で通知のスケジュール時刻になる',
        () async {
      final repo = InMemoryNotificationSettingsRepository();
      await repo.save(
        NotificationSettings(
          enabled: true,
          hour: 7,
          minute: 15,
          enabledKinds: NotificationKind.values.toSet(),
        ),
      );

      final service = NotificationService(plugin: plugin, settingsRepository: repo);
      await service.scheduleDailyReminder();

      final captured = verify(() => plugin.zonedSchedule(
            NotificationService.dailyReminderId,
            any(),
            any(),
            captureAny(),
            any(),
            androidScheduleMode: any(named: 'androidScheduleMode'),
            uiLocalNotificationDateInterpretation:
                any(named: 'uiLocalNotificationDateInterpretation'),
            matchDateTimeComponents: DateTimeComponents.time,
            payload: any(named: 'payload'),
          )).captured.single as tz.TZDateTime;

      expect(captured.hour, 7);
      expect(captured.minute, 15);
    });
  });

  group('親探針: 移行の一回性と種類別ON/OFFの保存', () {
    test('旧キーからの移行は初回のみで、以後は旧キーを書き換えても新キーが優先される',
        () async {
      SharedPreferences.setMockInitialValues({
        'notification_enabled': false,
        'notification_hour': 6,
        'notification_minute': 45,
      });
      final repo = InMemoryNotificationSettingsRepository();
      final service = NotificationService(plugin: plugin, settingsRepository: repo);

      final first = await service.loadSettings();
      expect(first.enabled, false);
      expect(first.hour, 6);
      expect(first.minute, 45);
      expect(repo.stored, isNotNull, reason: '移行時は新キーへ書き戻される');

      // 旧キーを後から書き換えても、移行済みの新設定が正となる
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notification_enabled', true);
      await prefs.setInt('notification_hour', 23);

      final second = await service.loadSettings();
      expect(second.enabled, false);
      expect(second.hour, 6);
      expect(second.minute, 45);
    });

    test('saveSettings は種類別ON/OFFを保持したまま全体・時刻のみ更新する', () async {
      final repo = InMemoryNotificationSettingsRepository();
      final service = NotificationService(plugin: plugin, settingsRepository: repo);
      await repo.save(
        NotificationSettings(
          enabled: true,
          hour: 21,
          minute: 0,
          enabledKinds: {NotificationKind.dailyReminder},
        ),
      );

      await service.saveSettings(enabled: false, hour: 8, minute: 30);

      expect(repo.stored!.enabledKinds, {NotificationKind.dailyReminder});
      expect(repo.stored!.enabled, false);
      expect(repo.stored!.hour, 8);
      expect(repo.stored!.minute, 30);
    });

    test('種類別OFF（budgetAlert）は予算超過アラートの表示を抑止する', () async {
      final repo = InMemoryNotificationSettingsRepository();
      await repo.save(
        NotificationSettings(
          enabled: true,
          hour: 21,
          minute: 0,
          enabledKinds: {NotificationKind.dailyReminder},
        ),
      );
      final service = NotificationService(plugin: plugin, settingsRepository: repo);

      await service.sendBudgetAlert('今月の予算を超えました');

      verifyNever(() => plugin.show(
            NotificationService.budgetAlertId,
            any(),
            any(),
            any(),
            payload: any(named: 'payload'),
          ));
    });

    test('種類別OFF（dailyReminder）は全体ONでもリマインドを止める', () async {
      final repo = InMemoryNotificationSettingsRepository();
      await repo.save(
        NotificationSettings(
          enabled: true,
          hour: 21,
          minute: 0,
          enabledKinds: {NotificationKind.budgetAlert},
        ),
      );
      final service = NotificationService(plugin: plugin, settingsRepository: repo);

      await service.scheduleDailyReminder();

      verify(() => plugin.cancel(NotificationService.dailyReminderId))
          .called(1);
    });
  });
}
