import 'weekly_quest.dart';

/// アクティブな週間クエストの状態
enum WeeklyQuestStatus {
  /// 選択待ち（候補として提示されたが、まだ選択されていない）
  pending,

  /// 挑戦中（ユーザーが選択し、現在進行中）
  active,

  /// 達成（期間内に目標を達成）
  completed,

  /// 失敗（期間内に目標を達成できなかった）
  failed;

  /// 表示用ラベル（日本語）
  String get label {
    switch (this) {
      case WeeklyQuestStatus.pending:
        return '選択待ち';
      case WeeklyQuestStatus.active:
        return '挑戦中';
      case WeeklyQuestStatus.completed:
        return '達成';
      case WeeklyQuestStatus.failed:
        return '失敗';
    }
  }
}

/// アクティブな週間クエスト
///
/// [WeeklyQuest] をラップし、選択状態・進行状態を管理する。
class ActiveWeeklyQuest {
  /// 元の週間クエスト
  final WeeklyQuest quest;

  /// 現在の状態
  final WeeklyQuestStatus status;

  /// 選択日時（ユーザーがこのクエストを選んだ日時）
  final DateTime? selectedAt;

  const ActiveWeeklyQuest({
    required this.quest,
    this.status = WeeklyQuestStatus.pending,
    this.selectedAt,
  });

  /// このクエストが現在挑戦中か
  bool get isActive => status == WeeklyQuestStatus.active;

  /// クエストを選択し、active状態に遷移する
  ActiveWeeklyQuest activate() {
    return ActiveWeeklyQuest(
      quest: quest,
      status: WeeklyQuestStatus.active,
      selectedAt: DateTime.now(),
    );
  }

  /// クエストを達成済みにする
  ActiveWeeklyQuest complete() {
    return ActiveWeeklyQuest(
      quest: quest,
      status: WeeklyQuestStatus.completed,
      selectedAt: selectedAt,
    );
  }

  /// クエストを失敗にする
  ActiveWeeklyQuest fail() {
    return ActiveWeeklyQuest(
      quest: quest,
      status: WeeklyQuestStatus.failed,
      selectedAt: selectedAt,
    );
  }

  /// JSONから復元
  factory ActiveWeeklyQuest.fromJson(Map<String, dynamic> json) {
    return ActiveWeeklyQuest(
      quest: WeeklyQuest.fromJson(
          Map<String, dynamic>.from(json['quest'] as Map)),
      status: WeeklyQuestStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => WeeklyQuestStatus.pending,
      ),
      selectedAt: json['selectedAt'] != null
          ? DateTime.parse(json['selectedAt'] as String)
          : null,
    );
  }

  /// JSONに変換
  Map<String, dynamic> toJson() {
    return {
      'quest': quest.toJson(),
      'status': status.name,
      if (selectedAt != null) 'selectedAt': selectedAt!.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActiveWeeklyQuest &&
          runtimeType == other.runtimeType &&
          quest.id == other.quest.id &&
          status == other.status;

  @override
  int get hashCode => quest.id.hashCode ^ status.hashCode;

  @override
  String toString() =>
      'ActiveWeeklyQuest(id: ${quest.id}, title: ${quest.title}, status: ${status.name})';
}
