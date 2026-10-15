import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:kozuchi/features/notification_settings/data/notification_settings_repository.dart';
import 'package:kozuchi/features/notification_settings/domain/notification_settings.dart';
import 'package:kozuchi/features/notification_settings/domain/notification_settings_resolver.dart';

/// ローカル通知基盤（kozuchi 家計簿RPG用）。
///
/// flutter_local_notifications + timezone で以下を提供する:
/// - デイリー記帳リマインド（毎日設定時刻に1回）
/// - 予算超過アラート（即時通知）
/// - テスト通知（即時表示）
///
/// 通知設定（全体ON/OFF・時刻・種類別ON/OFF）の出所は
/// [NotificationSettingsRepository]（SharedPreferences キー
/// `notification_settings_v1`）である。旧キー
/// （notification_enabled / notification_hour / notification_minute）が
/// 残る環境からは初回読み出し時に [NotificationSettingsResolver] 経由で
/// 新キーへ移行する。種類別OFFは scheduleDailyReminder / sendBudgetAlert
/// の実行時に [NotificationSettingsResolver.isActive] で判定する。
/// プラグイン・設定リポジトリはコンストラクタ注入可能で、試練（テスト）
/// では mocktail / InMemory リポジトリで検証できる。
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
  final NotificationSettingsRepository _settingsRepository;

  NotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    NotificationSettingsRepository? settingsRepository,
  })  : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
        _settingsRepository =
            settingsRepository ?? const SharedPreferencesNotificationSettingsRepository();

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

  // ── 設定の読み書き（NotificationSettingsRepository） ──

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  /// 実効通知設定を読み出す。
  ///
  /// 出所は [NotificationSettingsRepository]（キー notification_settings_v1）。
  /// 新キーが未保存で旧キー（notification_enabled / notification_hour /
  /// notification_minute）が存在する場合は、旧値から実効設定を組み立て、
  /// 初回のみ新キーへ書き戻す（後方互換マイグレーション）。
  Future<NotificationSettings> loadSettings() async {
    final stored = await _settingsRepository.load();
    final prefs = await _prefs();
    final legacy = LegacyNotificationSettings(
      enabled: prefs.getBool(_keyEnabled),
      hour: prefs.getInt(_keyHour),
      minute: prefs.getInt(_keyMinute),
    );
    // 保存済み設定の有無はリポジトリに問い合わせる。
    final hasStored = await _settingsRepository.hasStoredSettings();

    final effective = NotificationSettingsResolver.resolve(
      stored: stored,
      hasStoredSettings: hasStored,
      legacy: legacy,
    );

    if (NotificationSettingsResolver.needsMigration(
      hasStoredSettings: hasStored,
      legacy: legacy,
    )) {
      await _settingsRepository.save(effective);
    }
    return effective;
  }

  Future<bool> isEnabled() async => (await loadSettings()).enabled;

  Future<int> getReminderHour() async => (await loadSettings()).hour;

  Future<int> getReminderMinute() async => (await loadSettings()).minute;

  /// 通知設定（有効/無効・リマインド時刻）を
  /// [NotificationSettingsRepository]（キー notification_settings_v1）へ
  /// 永続化する。種類別ON/OFFは現設定を引き継ぐ。
  Future<void> saveSettings({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    final current = await loadSettings();
    await _settingsRepository.save(
      current.copyWith(enabled: enabled, hour: hour, minute: minute),
    );
  }

  // ── デイリー記帳リマインド ──

  /// 設定に基づきデイリー記帳リマインドをスケジュールする。
  /// 全体OFF または dailyReminder 種類OFF時はリマインドをキャンセルする。
  Future<void> scheduleDailyReminder() async {
    final settings = await loadSettings();
    if (!NotificationSettingsResolver.isActive(
      settings,
      NotificationKind.dailyReminder,
    )) {
      await _plugin.cancel(dailyReminderId);
      return;
    }

    final hour = settings.hour;
    final minute = settings.minute;
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
  /// 全体OFF または budgetAlert 種類OFF時は表示せず終了する。
  Future<void> sendBudgetAlert(String message) async {
    final settings = await loadSettings();
    if (!NotificationSettingsResolver.isActive(
      settings,
      NotificationKind.budgetAlert,
    )) {
      debugPrint(
        '[NotificationService] 予算超過アラートは無効のため送信しない: $message',
      );
      return;
    }
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
