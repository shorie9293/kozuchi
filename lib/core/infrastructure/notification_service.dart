import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// ローカル通知基盤（kozuchi 家計簿RPG用）。
///
/// flutter_local_notifications + timezone で以下を提供する:
/// - デイリー記帳リマインド（毎日設定時刻に1回）
/// - 予算超過アラート（即時通知）
/// - テスト通知（即時表示）
///
/// 有効/無効・リマインド時刻は shared_preferences に永続化する。
/// プラグインはコンストラクタ注入可能で、試練（テスト）では mocktail で
/// モックして検証できる。
class NotificationService {
  // ── 永続化キー ──
  static const _keyEnabled = 'notification_enabled';
  static const _keyHour = 'notification_hour';
  static const _keyMinute = 'notification_minute';

  // ── 通知ID ──
  static const int dailyReminderId = 1;
  static const int budgetAlertId = 2;
  static const int testNotificationId = 999;

  // ── 通知チャンネル ──
  static const _channelReminder = 'kozuchi_reminder';
  static const _channelBudget = 'kozuchi_budget';
  static const _channelTest = 'kozuchi_test';

  final FlutterLocalNotificationsPlugin _plugin;

  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// timezone 初期化とプラグイン初期化、通知チャンネル作成を行う。
  ///
  /// アプリ起動時に1回だけ呼ぶ。権限リクエストは行わない
  /// （runApp()前にActivityがないためダイアログを表示できない）。
  Future<void> initialize() async {
    _initializeTimeZone();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: android, iOS: darwin);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint(
          '[NotificationService] 通知タップ: id=${response.id}, '
          'payload=${response.payload}',
        );
      },
    );

    await _createNotificationChannels();
  }

  /// timezone データを初期化し、端末の実タイムゾーンオフセットと
  /// tz.local が食い違う場合に正しいタイムゾーンへ上書きする。
  void _initializeTimeZone() {
    tzdata.initializeTimeZones();

    final deviceOffset = DateTime.now().timeZoneOffset;
    final tzLocalOffset = tz.TZDateTime.now(tz.local).timeZoneOffset;

    debugPrint('[NotificationService] 端末オフセット: $deviceOffset');
    debugPrint(
      '[NotificationService] tz.local: ${tz.local.name} '
      '(offset: $tzLocalOffset)',
    );

    if (deviceOffset != tzLocalOffset) {
      final correctTzName = _findTimezoneByOffset(deviceOffset);
      if (correctTzName != null) {
        debugPrint(
          '[NotificationService] タイムゾーンを上書き: '
          '${tz.local.name} → $correctTzName',
        );
        tz.setLocalLocation(tz.getLocation(correctTzName));
      } else {
        debugPrint(
          '[NotificationService] 警告: オフセット $deviceOffset に一致する'
          'タイムゾーンが見つかりません',
        );
      }
    } else {
      debugPrint(
        '[NotificationService] タイムゾーンは正しいです: ${tz.local.name}',
      );
    }
  }

  /// 指定オフセットに一致するIANAタイムゾーンを探索する。
  /// 完全一致がなければ null を返す。
  String? _findTimezoneByOffset(Duration offset) {
    final preferredZones = [
      'Asia/Tokyo',
      'Asia/Seoul',
      'Asia/Shanghai',
      'Asia/Taipei',
      'Asia/Hong_Kong',
      'Asia/Singapore',
      'Asia/Kolkata',
      'Europe/London',
      'Europe/Berlin',
      'Europe/Paris',
      'America/New_York',
      'America/Chicago',
      'America/Denver',
      'America/Los_Angeles',
      'Pacific/Auckland',
      'Australia/Sydney',
      'UTC',
    ];

    for (final zoneName in preferredZones) {
      try {
        final location = tz.getLocation(zoneName);
        final now = tz.TZDateTime.now(location);
        if (now.timeZoneOffset == offset) {
          return zoneName;
        }
      } catch (_) {
        // 無効なゾーン名はスキップ
      }
    }

    for (final entry in tz.timeZoneDatabase.locations.entries) {
      try {
        final now = tz.TZDateTime.now(entry.value);
        if (now.timeZoneOffset == offset) {
          return entry.key;
        }
      } catch (_) {
        // 無効なゾーン名はスキップ
      }
    }

    return null;
  }

  /// Android 8+ の通知チャンネルを明示的に作成する。
  Future<void> _createNotificationChannels() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelReminder,
        '記帳リマインド',
        description: '毎日の記帳を促す通知',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelBudget,
        '予算超過アラート',
        description: '予算を超えた際のアラート',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelTest,
        'テスト通知',
        description: '通知機能のテスト用',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );

    debugPrint('[NotificationService] 通知チャンネルを作成しました');
  }

  /// 通知権限をリクエストする。Android 13+ では実行時ダイアログが表示される。
  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      debugPrint('[NotificationService] 通知権限: $granted');
      return granted ?? false;
    }
    return true;
  }

  /// Android 12+ で正確なアラーム（SCHEDULE_EXACT_ALARM）権限があるか確認する。
  Future<bool> canScheduleExactAlarms() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;
    try {
      final canSchedule = await android
          .canScheduleExactNotifications()
          .timeout(const Duration(seconds: 2));
      return canSchedule ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 使用するスケジュールモードを決定する。
  /// exact 権限があれば exactAllowWhileIdle、なければ inexactAllowWhileIdle。
  Future<AndroidScheduleMode> _getScheduleMode() async {
    if (await canScheduleExactAlarms()) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }
    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  // ── 設定の読み書き（shared_preferences） ──

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<bool> isEnabled() async {
    final prefs = await _prefs();
    return prefs.getBool(_keyEnabled) ?? true;
  }

  Future<int> getReminderHour() async {
    final prefs = await _prefs();
    return prefs.getInt(_keyHour) ?? 21;
  }

  Future<int> getReminderMinute() async {
    final prefs = await _prefs();
    return prefs.getInt(_keyMinute) ?? 0;
  }

  /// 通知設定（有効/無効・リマインド時刻）を永続化する。
  Future<void> saveSettings({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    final prefs = await _prefs();
    await prefs.setBool(_keyEnabled, enabled);
    await prefs.setInt(_keyHour, hour);
    await prefs.setInt(_keyMinute, minute);
  }

  // ── デイリー記帳リマインド ──

  /// 設定に基づきデイリー記帳リマインドをスケジュールする。
  /// 無効時はリマインドをキャンセルする。
  Future<void> scheduleDailyReminder() async {
    if (!await isEnabled()) {
      await _plugin.cancel(dailyReminderId);
      return;
    }

    final hour = await getReminderHour();
    final minute = await getReminderMinute();
    final scheduleMode = await _getScheduleMode();
    final scheduledDate = nextInstanceOfTime(hour, minute);

    debugPrint(
      '[NotificationService] 記帳リマインドをスケジュール: '
      '$hour:$minute → $scheduledDate (mode: $scheduleMode)',
    );

    await _plugin.zonedSchedule(
      dailyReminderId,
      '📒 記帳の刻',
      '今日の支出を記帳しましょう。小槌の力で家計を守るのです。',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelReminder,
          '記帳リマインド',
          channelDescription: '毎日の記帳を促す通知',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// 予算超過アラートを即時表示する。
  Future<void> sendBudgetAlert(String message) async {
    debugPrint('[NotificationService] 予算超過アラートを送信: $message');
    await _plugin.show(
      budgetAlertId,
      '💥 予算超過',
      message,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelBudget,
          '予算超過アラート',
          channelDescription: '予算を超えた際のアラート',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// テスト通知を即時表示する。通知機能の動作確認用。
  Future<void> sendTestNotification() async {
    debugPrint('[NotificationService] テスト通知を送信します');
    await _plugin.show(
      testNotificationId,
      '🔔 テスト通知',
      '通知機能は正常に動作しています！',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelTest,
          'テスト通知',
          channelDescription: '通知機能のテスト用',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// 全ての通知（リマインド・予算超過・テスト）をキャンセルする。
  Future<void> cancelAll() async {
    await _plugin.cancel(dailyReminderId);
    await _plugin.cancel(budgetAlertId);
    await _plugin.cancel(testNotificationId);
  }

  /// 指定時刻の次の発生時刻（tz.local 基準）を返す。
  /// 今日の時刻を過ぎていれば翌日を返す。
  tz.TZDateTime nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
