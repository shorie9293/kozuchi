import 'dart:convert';

/// 通知の種類。
enum NotificationKind {
  dailyReminder(
    storageKey: 'daily_reminder',
    label: '記帳リマインド',
    description: '毎日の記帳を促す通知',
  ),
  budgetAlert(
    storageKey: 'budget_alert',
    label: '予算超過アラート',
    description: '予算を超えた際のアラート',
  ),
  recurringTransaction(
    storageKey: 'recurring_transaction',
    label: '定期取引の通知',
    description: '定期取引・サブスクの引落し通知',
  );

  const NotificationKind({
    required this.storageKey,
    required this.label,
    required this.description,
  });

  /// 永続化用のキー。
  final String storageKey;

  /// 表示名。
  final String label;

  /// 説明文。
  final String description;

  /// storageKey から種類を復元する（未知のキーは null）。
  static NotificationKind? fromStorageKey(String key) {
    for (final kind in NotificationKind.values) {
      if (kind.storageKey == key) return kind;
    }
    return null;
  }
}

/// 通知設定（全体ON/OFF・リマインド時刻・種類別ON/OFF）。
class NotificationSettings {
  /// 通知機能の全体ON/OFF。
  final bool enabled;

  /// リマインド時刻（時）。0..23。
  final int hour;

  /// リマインド時刻（分）。0..59。
  final int minute;

  /// 有効化されている通知の種類。
  final Set<NotificationKind> enabledKinds;

  NotificationSettings({
    required this.enabled,
    required this.hour,
    required this.minute,
    required this.enabledKinds,
  }) {
    if (hour < 0 || hour > 23) {
      throw ArgumentError.value(hour, 'hour', '0..23');
    }
    if (minute < 0 || minute > 59) {
      throw ArgumentError.value(minute, 'minute', '0..59');
    }
  }

  /// 既定設定：全体ON、21:00、全種有効。
  factory NotificationSettings.defaults() => NotificationSettings(
        enabled: true,
        hour: 21,
        minute: 0,
        enabledKinds: NotificationKind.values.toSet(),
      );

  /// 指定種類が有効か。
  bool isKindEnabled(NotificationKind kind) => enabledKinds.contains(kind);

  /// 時刻の表示ラベル（ゼロ埋め "HH:mm"）。
  String get timeLabel =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// 値を一部だけ差し替えた新しいインスタンスを返す。
  NotificationSettings copyWith({
    bool? enabled,
    int? hour,
    int? minute,
    Set<NotificationKind>? enabledKinds,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      enabledKinds: enabledKinds ?? this.enabledKinds,
    );
  }

  /// 種類のON/OFFを切り替えた新しいインスタンスを返す
  /// （含まれれば除去、無ければ追加）。
  NotificationSettings toggleKind(NotificationKind kind) {
    final next = Set<NotificationKind>.of(enabledKinds);
    if (next.contains(kind)) {
      next.remove(kind);
    } else {
      next.add(kind);
    }
    return NotificationSettings(
      enabled: enabled,
      hour: hour,
      minute: minute,
      enabledKinds: next,
    );
  }

  /// JSON 形式へ変換する。enabledKinds は storageKey のリストで保存する。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'enabled': enabled,
        'hour': hour,
        'minute': minute,
        'enabledKinds': enabledKinds.map((k) => k.storageKey).toList(),
      };

  /// JSON 形式から復元する（tolerant）。
  ///
  /// - 欠落キーは既定値
  /// - hour/minute が範囲外や非intなら既定値（21/0）へフォールバック
  /// - enabledKinds は未知の storageKey を無視、欠落時は全種有効
  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    var hour = 21;
    final rawHour = json['hour'];
    if (rawHour is int && rawHour >= 0 && rawHour <= 23) {
      hour = rawHour;
    }

    var minute = 0;
    final rawMinute = json['minute'];
    if (rawMinute is int && rawMinute >= 0 && rawMinute <= 59) {
      minute = rawMinute;
    }

    var kinds = NotificationKind.values.toSet();
    final rawKinds = json['enabledKinds'];
    if (rawKinds is List) {
      final parsed = <NotificationKind>{};
      for (final item in rawKinds) {
        final kind = NotificationKind.fromStorageKey(item.toString());
        if (kind != null) parsed.add(kind);
      }
      kinds = parsed;
    }

    return NotificationSettings(
      enabled: json['enabled'] is bool ? json['enabled'] as bool : true,
      hour: hour,
      minute: minute,
      enabledKinds: kinds,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationSettings &&
        other.enabled == enabled &&
        other.hour == hour &&
        other.minute == minute &&
        const SetEquality().equals(other.enabledKinds, enabledKinds);
  }

  @override
  int get hashCode => Object.hash(
        enabled,
        hour,
        minute,
        const SetEquality().hash(enabledKinds),
      );
}

/// Set の順序非依存の等値性・ハッシュ計算のための小ヘルパー。
class SetEquality {
  const SetEquality();

  bool equals(Set<Object?> a, Set<Object?> b) {
    if (a.length != b.length) return false;
    for (final item in a) {
      if (!b.contains(item)) return false;
    }
    return true;
  }

  int hash(Set<Object?> set) {
    var combined = 0;
    for (final item in set) {
      combined ^= item.hashCode;
    }
    return combined;
  }
}

/// JSON 文字列との往復ユーティリティ（dart:convert の利用箇所を確保）。
String encodeNotificationSettings(NotificationSettings settings) =>
    jsonEncode(settings.toJson());
