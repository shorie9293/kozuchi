import 'package:kozuchi/features/weekly_quest/domain/models/active_weekly_quest.dart';
import 'package:kozuchi/features/weekly_quest/domain/models/weekly_quest.dart';

/// 週次クエストの週単位スナップショット（永続化単位）。
///
/// `weekKey` が現在週と一致する限り再生成しない、という判定の鍵になる。
class WeeklyQuestState {
  /// 対象週の識別子（`'YYYY-MM-DD'`。月曜の日付）。
  final String weekKey;

  /// 未選択の候補クエスト。
  final List<WeeklyQuest> pending;

  /// 選択中のクエスト（未選択なら null）。
  final ActiveWeeklyQuest? active;

  /// 生成日時。
  final DateTime generatedAt;

  const WeeklyQuestState({
    required this.weekKey,
    required this.pending,
    this.active,
    required this.generatedAt,
  });

  /// 候補が残っているか。
  bool get hasPending => pending.isNotEmpty;

  /// 挑戦中のクエストがあるか。
  bool get isActive => active != null;

  /// 候補もアクティブも無い空状態か。
  bool get isEmpty => pending.isEmpty && active == null;

  /// 一部フィールドのみ差し替えた新しい状態を返す。
  ///
  /// [clearActive] を true にすると active を null に戻せる
  /// （null 合体では「未指定」と「null 上書き」を区別できないため）。
  WeeklyQuestState copyWith({
    List<WeeklyQuest>? pending,
    ActiveWeeklyQuest? active,
    bool clearActive = false,
  }) {
    return WeeklyQuestState(
      weekKey: weekKey,
      pending: pending ?? this.pending,
      active: clearActive ? null : (active ?? this.active),
      generatedAt: generatedAt,
    );
  }

  /// JSON へ変換。
  Map<String, dynamic> toJson() {
    return {
      'weekKey': weekKey,
      'pending': pending.map((q) => q.toJson()).toList(),
      if (active != null) 'active': active!.toJson(),
      'generatedAt': generatedAt.toIso8601String(),
    };
  }

  /// JSON から復元。
  ///
  /// 壊れた要素（型不一致・欠損・日付不正）は読み飛ばし、例外は投げない。
  factory WeeklyQuestState.fromJson(Map<String, dynamic> json) {
    final weekKey = json['weekKey'] is String ? json['weekKey'] as String : '';

    final pending = <WeeklyQuest>[];
    final rawPending = json['pending'];
    if (rawPending is List) {
      for (final element in rawPending) {
        try {
          if (element is Map) {
            pending.add(
              WeeklyQuest.fromJson(Map<String, dynamic>.from(element)),
            );
          }
        } catch (_) {
          // 壊れた要素は捨てる。
        }
      }
    }

    ActiveWeeklyQuest? active;
    final rawActive = json['active'];
    if (rawActive is Map) {
      try {
        active = ActiveWeeklyQuest.fromJson(
          Map<String, dynamic>.from(rawActive),
        );
      } catch (_) {
        active = null;
      }
    }

    DateTime generatedAt;
    try {
      final rawGeneratedAt = json['generatedAt'];
      generatedAt = rawGeneratedAt is String
          ? DateTime.parse(rawGeneratedAt)
          : DateTime.fromMillisecondsSinceEpoch(0);
    } catch (_) {
      generatedAt = DateTime.fromMillisecondsSinceEpoch(0);
    }

    return WeeklyQuestState(
      weekKey: weekKey,
      pending: pending,
      active: active,
      generatedAt: generatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! WeeklyQuestState) return false;
    if (weekKey != other.weekKey) return false;
    if (generatedAt != other.generatedAt) return false;
    if (active != other.active) return false;
    if (pending.length != other.pending.length) return false;
    for (var i = 0; i < pending.length; i++) {
      if (pending[i] != other.pending[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => weekKey.hashCode ^
      generatedAt.hashCode ^
      active.hashCode ^
      pending.length.hashCode;

  @override
  String toString() =>
      'WeeklyQuestState(week: $weekKey, pending: ${pending.length}, '
      'active: ${active?.quest.id})';
}
