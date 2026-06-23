import 'dart:math';

/// デイリークエストのタイプ
///
/// 各タイプは異なる検出条件・デフォルトEXP報酬・SATORIペナルティを持つ。
enum DailyQuestType {
  /// 自分に¥N使え（自分への投資・自己ケアカテゴリでの支出）
  spendOnSelf(
    label: '自分に使え',
    defaultExpReward: 80,
    defaultSatoriPenalty: 10,
  ),

  /// レシートをN枚撮れ（レシート撮影回数）
  receiptScan(
    label: 'レシート撮影',
    defaultExpReward: 100,
    defaultSatoriPenalty: 10,
  ),

  /// 新しいカテゴリで支出せよ（最近使っていないカテゴリの開拓）
  newCategory(
    label: '新カテゴリ支出',
    defaultExpReward: 120,
    defaultSatoriPenalty: 10,
  ),

  /// 今日の支出を¥N以内に抑えよ（予算管理）
  underBudget(
    label: '予算以内',
    defaultExpReward: 60,
    defaultSatoriPenalty: 5,
  ),

  /// 今日は1円も使うな（完全無支出）
  noSpending(
    label: '無支出の日',
    defaultExpReward: 150,
    defaultSatoriPenalty: 20,
  );

  const DailyQuestType({
    required this.label,
    required this.defaultExpReward,
    required this.defaultSatoriPenalty,
  });

  /// 表示用ラベル
  final String label;

  /// デフォルトEXP報酬
  final int defaultExpReward;

  /// デフォルトSATORIペナルティ（未達成時）
  final int defaultSatoriPenalty;

  /// 名前からenumを解決する（不明な場合はspendOnSelfにフォールバック）
  static DailyQuestType fromName(String name) {
    return DailyQuestType.values.firstWhere(
      (t) => t.name == name,
      orElse: () => DailyQuestType.spendOnSelf,
    );
  }
}

/// デイリークエスト
///
/// 日替わりで割り当てられる1つのクエスト。
/// 不変（immutable）であり、状態変更は新しいインスタンスを返す。
class DailyQuest {
  /// クエストの一意なID
  final String id;

  /// クエストタイプ
  final DailyQuestType type;

  /// クエストのタイトル
  final String title;

  /// クエストの説明
  final String description;

  /// 目標値（例：¥1,000、3枚、1回）
  final int targetValue;

  /// 現在の進捗値（0〜targetValue）
  final int currentProgress;

  /// 達成したか
  final bool isCompleted;

  /// 失敗したか（日付跨ぎで未達成の場合）
  final bool isFailed;

  /// 割り当てられた日時
  final DateTime dateAssigned;

  /// 達成日時（未達成はnull）
  final DateTime? dateCompleted;

  /// EXP報酬
  final int expReward;

  /// SATORIペナルティ（未達成時に喪失するSATORI値）
  final int satoriPenalty;

  DailyQuest({
    String? id,
    required this.type,
    required this.title,
    this.description = '',
    required this.targetValue,
    this.currentProgress = 0,
    this.isCompleted = false,
    this.isFailed = false,
    DateTime? dateAssigned,
    this.dateCompleted,
    int? expReward,
    int? satoriPenalty,
  })  : id = id ?? _generateId(),
        dateAssigned = dateAssigned ?? DateTime.now(),
        expReward = expReward ?? type.defaultExpReward,
        satoriPenalty = satoriPenalty ?? type.defaultSatoriPenalty;

  /// ランダムなIDを生成する
  static String _generateId() {
    final random = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(12, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// 進捗度（0.0〜1.0）
  double get progressRatio {
    if (targetValue <= 0) return 1.0;
    return (currentProgress / targetValue).clamp(0.0, 1.0);
  }

  /// 進捗を更新する
  ///
  /// [newProgress] が目標値以上なら達成状態になる。
  /// すでに達成済みの場合は更新しない（達成状態を維持）。
  DailyQuest updateProgress(int newProgress) {
    if (isCompleted) return this;

    final clamped = newProgress.clamp(0, targetValue);
    final completed = clamped >= targetValue;

    return DailyQuest(
      id: id,
      type: type,
      title: title,
      description: description,
      targetValue: targetValue,
      currentProgress: clamped,
      isCompleted: completed,
      isFailed: isFailed,
      dateAssigned: dateAssigned,
      dateCompleted: completed ? DateTime.now() : dateCompleted,
      expReward: expReward,
      satoriPenalty: satoriPenalty,
    );
  }

  /// 失敗としてマークする
  DailyQuest markAsFailed() {
    return DailyQuest(
      id: id,
      type: type,
      title: title,
      description: description,
      targetValue: targetValue,
      currentProgress: currentProgress,
      isCompleted: false,
      isFailed: true,
      dateAssigned: dateAssigned,
      dateCompleted: dateCompleted,
      expReward: expReward,
      satoriPenalty: satoriPenalty,
    );
  }

  /// JSONから復元
  factory DailyQuest.fromJson(Map<String, dynamic> json) {
    final type = DailyQuestType.fromName(
      json['type'] as String? ?? 'spendOnSelf',
    );
    return DailyQuest(
      id: json['id'] as String?,
      type: type,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      targetValue: json['targetValue'] as int? ?? 0,
      currentProgress: json['currentProgress'] as int? ?? 0,
      isCompleted: json['isCompleted'] as bool? ?? false,
      isFailed: json['isFailed'] as bool? ?? false,
      dateAssigned: json['dateAssigned'] != null
          ? DateTime.tryParse(json['dateAssigned'] as String) ?? DateTime.now()
          : DateTime.now(),
      dateCompleted: json['dateCompleted'] != null
          ? DateTime.tryParse(json['dateCompleted'] as String)
          : null,
      expReward: json['expReward'] as int? ?? type.defaultExpReward,
      satoriPenalty:
          json['satoriPenalty'] as int? ?? type.defaultSatoriPenalty,
    );
  }

  /// JSONに変換
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'description': description,
      'targetValue': targetValue,
      'currentProgress': currentProgress,
      'isCompleted': isCompleted,
      'isFailed': isFailed,
      'dateAssigned': dateAssigned.toIso8601String(),
      'dateCompleted': dateCompleted?.toIso8601String(),
      'expReward': expReward,
      'satoriPenalty': satoriPenalty,
    };
  }
}

/// デイリークエストの日次状態
///
/// その日に割り当てられた全クエストを保持・管理する。
class DailyQuestState {
  /// この状態が属する日付
  final DateTime date;

  /// 割り当てられたクエスト一覧（最大3件）
  final List<DailyQuest> quests;

  DailyQuestState({
    DateTime? date,
    this.quests = const [],
  }) : date = date ?? DateTime.now();

  /// 本日かどうか
  bool get isToday {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// 未完了クエスト
  List<DailyQuest> get pendingQuests =>
      quests.where((q) => !q.isCompleted && !q.isFailed).toList();

  /// 完了済みクエスト
  List<DailyQuest> get completedQuests =>
      quests.where((q) => q.isCompleted).toList();

  /// 全クエストが完了したか
  bool get isAllCompleted =>
      quests.isNotEmpty && quests.every((q) => q.isCompleted);

  /// 失敗したクエストのSATORIペナルティ合計
  int get totalSatoriPenalty =>
      quests.where((q) => q.isFailed).fold(0, (sum, q) => sum + q.satoriPenalty);

  /// 空の状態を生成
  factory DailyQuestState.empty() => DailyQuestState(quests: []);

  /// JSONから復元
  factory DailyQuestState.fromJson(Map<String, dynamic> json) {
    final questsJson = json['quests'] as List<dynamic>? ?? [];
    final quests = questsJson
        .map((q) => DailyQuest.fromJson(q as Map<String, dynamic>))
        .toList();
    final date = json['date'] != null
        ? DateTime.tryParse(json['date'] as String) ?? DateTime.now()
        : DateTime.now();

    return DailyQuestState(date: date, quests: quests);
  }

  /// JSONに変換
  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'quests': quests.map((q) => q.toJson()).toList(),
    };
  }
}
