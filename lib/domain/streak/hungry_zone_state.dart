/// 飢餓地帯（Hungry Zone）の罰状態を表す不変モデル。
///
/// ストリーク途絶時に確率で発動するペナルティ状態。
/// クールダウン経過または帰還任務完了で終了する。
class HungryZoneState {
  /// 飢餓地帯が発動中か
  final bool isActive;

  /// ステータス乗数（1.0=通常、0.7=30%減 など）
  final double statMultiplier;

  /// クールダウン期間
  final Duration cooldownDuration;

  /// 発動日時（null = 未発動）
  final DateTime? activatedAt;

  /// 途絶時のストリーク日数（UI表示用）
  final int brokenStreakDays;

  /// 帰還任務を完了したか（早期脱出条件）
  final bool returnMissionCompleted;

  const HungryZoneState({
    this.isActive = false,
    this.statMultiplier = 1.0,
    this.cooldownDuration = const Duration(hours: 24),
    this.activatedAt,
    this.brokenStreakDays = 0,
    this.returnMissionCompleted = false,
  });

  /// 未発動（無罰）の初期状態を生成する
  factory HungryZoneState.inactive() => const HungryZoneState();

  /// クールダウンが経過したか判定する。
  ///
  /// [now] は現在日時。
  /// 未発動または activatedAt が null の場合は false を返す。
  bool isCooldownExpired(DateTime now) {
    if (!isActive || activatedAt == null) return false;
    return !now.isBefore(activatedAt!.add(cooldownDuration));
  }

  /// 飢餓地帯を脱出可能かを判定する。
  ///
  /// 以下のいずれかを満たせば true:
  /// - クールダウン経過
  /// - 帰還任務完了
  /// - もともと未発動
  bool isExitable(DateTime now) {
    if (!isActive) return true;
    return returnMissionCompleted || isCooldownExpired(now);
  }

  /// フィールドの一部を差し替えたコピーを返す。
  ///
  /// [activatedAt] に明示的に `null` を渡すと null クリアされる。
  /// Dart の null 安全の制約上、未指定と明示的 null を区別するため
  /// 内部で sentinel を用いている。
  static const _sentinel = Object();

  HungryZoneState copyWith({
    bool? isActive,
    double? statMultiplier,
    Duration? cooldownDuration,
    Object? activatedAt = _sentinel,
    int? brokenStreakDays,
    bool? returnMissionCompleted,
  }) {
    return HungryZoneState(
      isActive: isActive ?? this.isActive,
      statMultiplier: statMultiplier ?? this.statMultiplier,
      cooldownDuration: cooldownDuration ?? this.cooldownDuration,
      activatedAt: identical(activatedAt, _sentinel)
          ? this.activatedAt
          : activatedAt as DateTime?,
      brokenStreakDays: brokenStreakDays ?? this.brokenStreakDays,
      returnMissionCompleted:
          returnMissionCompleted ?? this.returnMissionCompleted,
    );
  }

  /// JSONから復元
  factory HungryZoneState.fromJson(Map<String, dynamic> json) {
    final dateStr = json['activatedAt'] as String?;
    return HungryZoneState(
      isActive: (json['isActive'] as bool?) ?? false,
      statMultiplier: (json['statMultiplier'] as num?)?.toDouble() ?? 1.0,
      cooldownDuration:
          Duration(hours: (json['cooldownHours'] as int?) ?? 24),
      activatedAt:
          dateStr != null ? DateTime.tryParse(dateStr) : null,
      brokenStreakDays: (json['brokenStreakDays'] as int?) ?? 0,
      returnMissionCompleted:
          (json['returnMissionCompleted'] as bool?) ?? false,
    );
  }

  /// JSONに変換
  Map<String, dynamic> toJson() {
    return {
      'isActive': isActive,
      'statMultiplier': statMultiplier,
      'cooldownHours': cooldownDuration.inHours,
      'activatedAt': activatedAt?.toIso8601String(),
      'brokenStreakDays': brokenStreakDays,
      'returnMissionCompleted': returnMissionCompleted,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HungryZoneState &&
          isActive == other.isActive &&
          statMultiplier == other.statMultiplier &&
          cooldownDuration == other.cooldownDuration &&
          activatedAt == other.activatedAt &&
          brokenStreakDays == other.brokenStreakDays &&
          returnMissionCompleted == other.returnMissionCompleted;

  @override
  int get hashCode => Object.hash(
        isActive,
        statMultiplier,
        cooldownDuration,
        activatedAt,
        brokenStreakDays,
        returnMissionCompleted,
      );

  @override
  String toString() =>
      'HungryZoneState(isActive: $isActive, statMultiplier: $statMultiplier, '
      'cooldownDuration: $cooldownDuration, activatedAt: $activatedAt, '
      'brokenStreakDays: $brokenStreakDays, '
      'returnMissionCompleted: $returnMissionCompleted)';
}
