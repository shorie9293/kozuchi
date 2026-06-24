/// ストリーク状態を表す不変モデル。
///
/// 連続日数・最長記録・最終活動日を保持する。
class StreakState {
  /// 現在の連続日数
  final int streakDays;

  /// 過去最長の連続日数
  final int longestStreak;

  /// 最後に活動を記録した日付（null = 未記録）
  final DateTime? lastActivityDate;

  const StreakState({
    this.streakDays = 0,
    this.longestStreak = 0,
    this.lastActivityDate,
  });

  /// 初期状態（未記録）を生成する
  factory StreakState.empty() => const StreakState();

  /// フィールドの一部を差し替えたコピーを返す。
  ///
  /// [lastActivityDate] に明示的に `null` を渡すと null クリアされる。
  /// Dart の null 安全の制約上、未指定と明示的 null を区別するため
  /// 内部で sentinel を用いている。
  static const _sentinel = Object();

  StreakState copyWith({
    int? streakDays,
    int? longestStreak,
    Object? lastActivityDate = _sentinel,
  }) {
    return StreakState(
      streakDays: streakDays ?? this.streakDays,
      longestStreak: longestStreak ?? this.longestStreak,
      lastActivityDate: identical(lastActivityDate, _sentinel)
          ? this.lastActivityDate
          : lastActivityDate as DateTime?,
    );
  }

  /// JSONから復元
  factory StreakState.fromJson(Map<String, dynamic> json) {
    final dateStr = json['lastActivityDate'] as String?;
    return StreakState(
      streakDays: (json['streakDays'] as int?) ?? 0,
      longestStreak: (json['longestStreak'] as int?) ?? 0,
      lastActivityDate:
          dateStr != null ? DateTime.tryParse(dateStr) : null,
    );
  }

  /// JSONに変換
  Map<String, dynamic> toJson() {
    return {
      'streakDays': streakDays,
      'longestStreak': longestStreak,
      'lastActivityDate': lastActivityDate?.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StreakState &&
          streakDays == other.streakDays &&
          longestStreak == other.longestStreak &&
          _sameDay(lastActivityDate, other.lastActivityDate);

  @override
  int get hashCode =>
      streakDays.hashCode ^ longestStreak.hashCode ^ lastActivityDate.hashCode;

  @override
  String toString() =>
      'StreakState(streakDays: $streakDays, longestStreak: $longestStreak, '
      'lastActivityDate: $lastActivityDate)';

  /// 二つのDateTimeが同日かを判定（null同士はtrue）
  static bool _sameDay(DateTime? a, DateTime? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
