import 'package:kozuchi/features/quiet_hours/domain/quiet_hours_policy.dart';

/// 静穏時間（おやすみモード）設定。不変・値等価。
///
/// 範囲検証は非constコンストラクタ本体で行う（assert は使わない）。
class QuietHoursSettings {
  /// 静穏時間の有効/無効。
  final bool enabled;

  /// 開始時刻（時）。0..23。
  final int startHour;

  /// 開始時刻（分）。0..59。
  final int startMinute;

  /// 終了時刻（時）。0..23。
  final int endHour;

  /// 終了時刻（分）。0..59。
  final int endMinute;

  /// 静穏時間中の通知方針。
  final QuietHoursPolicy policy;

  QuietHoursSettings({
    required this.enabled,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    required this.policy,
  }) {
    if (startHour < 0 || startHour > 23) {
      throw ArgumentError.value(startHour, 'startHour', '0..23');
    }
    if (startMinute < 0 || startMinute > 59) {
      throw ArgumentError.value(startMinute, 'startMinute', '0..59');
    }
    if (endHour < 0 || endHour > 23) {
      throw ArgumentError.value(endHour, 'endHour', '0..23');
    }
    if (endMinute < 0 || endMinute > 59) {
      throw ArgumentError.value(endMinute, 'endMinute', '0..59');
    }
  }

  /// 既定設定：無効・22:00-07:00・翌朝に繰り延べ。
  factory QuietHoursSettings.defaults() => QuietHoursSettings(
        enabled: false,
        startHour: 22,
        startMinute: 0,
        endHour: 7,
        endMinute: 0,
        policy: QuietHoursPolicy.defer,
      );

  /// 開始時刻を0時からの分に変換したもの。
  int get startMinutes => startHour * 60 + startMinute;

  /// 終了時刻を0時からの分に変換したもの。
  int get endMinutes => endHour * 60 + endMinute;

  /// 開始時刻の表示ラベル（'HH:mm'）。
  String get startLabel => _label(startHour, startMinute);

  /// 終了時刻の表示ラベル（'HH:mm'）。
  String get endLabel => _label(endHour, endMinute);

  static String _label(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// 一部だけ差し替えた新しいインスタンスを返す。
  QuietHoursSettings copyWith({
    bool? enabled,
    int? startHour,
    int? startMinute,
    int? endHour,
    int? endMinute,
    QuietHoursPolicy? policy,
  }) {
    return QuietHoursSettings(
      enabled: enabled ?? this.enabled,
      startHour: startHour ?? this.startHour,
      startMinute: startMinute ?? this.startMinute,
      endHour: endHour ?? this.endHour,
      endMinute: endMinute ?? this.endMinute,
      policy: policy ?? this.policy,
    );
  }

  /// JSON 形式へ変換する。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'enabled': enabled,
        'startHour': startHour,
        'startMinute': startMinute,
        'endHour': endHour,
        'endMinute': endMinute,
        'policy': policy.storageKey,
      };

  /// JSON 形式から復元する。
  ///
  /// 破損（型不正・範囲外）なら [QuietHoursSettings.defaults] を返す。
  /// 未知の policy は [QuietHoursPolicy.defer] にフォールバックする。
  factory QuietHoursSettings.fromJson(Map<String, dynamic> json) {
    final enabled = json['enabled'];
    final startHour = json['startHour'];
    final startMinute = json['startMinute'];
    final endHour = json['endHour'];
    final endMinute = json['endMinute'];

    bool validHour(Object? v) => v is int && v >= 0 && v <= 23;
    bool validMinute(Object? v) => v is int && v >= 0 && v <= 59;

    if (enabled is! bool ||
        !validHour(startHour) ||
        !validMinute(startMinute) ||
        !validHour(endHour) ||
        !validMinute(endMinute)) {
      return QuietHoursSettings.defaults();
    }

    return QuietHoursSettings(
      enabled: enabled,
      startHour: startHour as int,
      startMinute: startMinute as int,
      endHour: endHour as int,
      endMinute: endMinute as int,
      policy: QuietHoursPolicy.fromStorageKey(json['policy'].toString()),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QuietHoursSettings &&
        other.enabled == enabled &&
        other.startHour == startHour &&
        other.startMinute == startMinute &&
        other.endHour == endHour &&
        other.endMinute == endMinute &&
        other.policy == policy;
  }

  @override
  int get hashCode => Object.hash(
        enabled,
        startHour,
        startMinute,
        endHour,
        endMinute,
        policy,
      );

  @override
  String toString() => 'QuietHoursSettings(enabled: $enabled, '
      '$startLabel-$endLabel, policy: ${policy.storageKey})';
}
