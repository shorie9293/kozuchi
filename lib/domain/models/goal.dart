import 'package:kozuchi/domain/models/achievement.dart';

/// 目標の状態を表す列挙型
enum GoalStatus {
  /// 進行中の目標
  active,

  /// 達成済みの目標
  completed,
}

/// 目標モデル
///
/// ユーザーが設定する金銭的・習慣的な目標を表す。
/// 複数の目標を同時に並行管理可能。
/// SharedPreferences で永続化するための JSON シリアライズに対応。
class Goal {
  /// 目標の一意識別子（UUID v4）
  final String id;

  /// ユーザー識別子（将来のマルチユーザー対応用。現在は 'default'）
  final String userId;

  /// 目標の名称（例: 「月末までに¥50,000貯める」）
  final String title;

  /// 目標金額（円）。0の場合は金額目標なし（習慣目標等）
  final int targetAmount;

  /// 達成期限（nullの場合は期限なし）
  final DateTime? deadline;

  /// 現在の達成額（円）。デフォルトは0
  final int currentAmount;

  /// 目標の状態
  final GoalStatus status;

  /// 作成日時
  final DateTime createdAt;

  /// 最終更新日時
  final DateTime updatedAt;

  const Goal({
    required this.id,
    this.userId = 'default',
    required this.title,
    this.targetAmount = 0,
    this.deadline,
    this.currentAmount = 0,
    this.status = GoalStatus.active,
    required this.createdAt,
    required this.updatedAt,
  }) : assert(targetAmount >= 0, '目標金額は0以上である必要があります'),
       assert(currentAmount >= 0, '現在額は0以上である必要があります');

  /// 目標の進捗率（0.0〜1.0）
  ///
  /// targetAmount が 0 の場合は 0.0 を返す。
  double get progress {
    if (targetAmount == 0) return 0.0;
    return (currentAmount / targetAmount).clamp(0.0, 1.0);
  }

  /// 進捗率を百分率（0〜100）で返す
  int get progressPercent => (progress * 100).round();

  /// 期限切れかどうか
  bool get isOverdue {
    if (deadline == null) return false;
    return DateTime.now().isAfter(deadline!) && status == GoalStatus.active;
  }

  /// 残り日数（期限がない場合は null）
  int? get remainingDays {
    if (deadline == null) return null;
    return deadline!.difference(DateTime.now()).inDays;
  }

  /// JSONから復元
  factory Goal.fromJson(Map<String, dynamic> json) {
    return Goal(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? 'default',
      title: json['title'] as String? ?? '',
      targetAmount: json['targetAmount'] as int? ?? 0,
      deadline: json['deadline'] != null
          ? DateTime.tryParse(json['deadline'] as String)
          : null,
      currentAmount: json['currentAmount'] as int? ?? 0,
      status: _parseStatus(json['status'] as String?),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// JSONに変換
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'targetAmount': targetAmount,
      'deadline': deadline?.toIso8601String(),
      'currentAmount': currentAmount,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// 目標額を進捗更新したコピーを返す
  ///
  /// 目標額に達した場合は自動的に completed 状態になる。
  Goal updateProgress(int newAmount) {
    final clamped = newAmount.clamp(0, targetAmount > 0 ? targetAmount : newAmount);
    final newStatus = (targetAmount > 0 && clamped >= targetAmount)
        ? GoalStatus.completed
        : status;
    return Goal(
      id: id,
      userId: userId,
      title: title,
      targetAmount: targetAmount,
      deadline: deadline,
      currentAmount: clamped,
      status: newStatus,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// 状態を変更したコピーを返す
  Goal copyWithStatus(GoalStatus newStatus) {
    return Goal(
      id: id,
      userId: userId,
      title: title,
      targetAmount: targetAmount,
      deadline: deadline,
      currentAmount: currentAmount,
      status: newStatus,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// 目標達成時に獲得できる称号を生成する
  ///
  /// 目標額に応じた称号を返す。targetAmount が 0 の場合は習慣系の称号。
  Achievement? generateAchievement() {
    if (status != GoalStatus.completed) return null;
    return Achievement.forGoal(this);
  }

  /// 状態文字列をパース
  static GoalStatus _parseStatus(String? statusStr) {
    if (statusStr == 'completed') return GoalStatus.completed;
    return GoalStatus.active;
  }
}
