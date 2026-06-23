/// 週間クエスト（Weekly Challenge Quest）
///
/// アドバイザーが毎週月曜に自動発行する支出制限チャレンジ。
/// ユーザーの支出履歴を分析し、カテゴリ別の予算制限を提案する。
///
/// 例: 「今週は娯楽費を¥5,000以内に抑えよう」
class WeeklyQuest {
  /// 一意識別子（UUIDv4形式推奨）
  final String id;

  /// 短い挑戦タイトル（例: 「娯楽費を¥5,000以内に」）
  final String title;

  /// 詳細説明（守護神の口調で動機付け）
  final String description;

  /// 対象カテゴリ（例: '娯楽', '食費', '交通費', または '総支出'）
  final String targetCategory;

  /// 今週の予算上限（円）
  final int budgetLimit;

  /// 直近の週間平均支出（円） — 比較表示用
  final int currentAvgSpend;

  /// 難易度
  final QuestDifficulty difficulty;

  /// 生成日時
  final DateTime generatedAt;

  /// 対象週の月曜日
  final DateTime weekStart;

  /// 生成に使われたテンプレートID（バリエーション追跡用）
  final String templateId;

  const WeeklyQuest({
    required this.id,
    required this.title,
    required this.description,
    required this.targetCategory,
    required this.budgetLimit,
    required this.currentAvgSpend,
    required this.difficulty,
    required this.generatedAt,
    required this.weekStart,
    required this.templateId,
  }) : assert(budgetLimit > 0, 'budgetLimit must be positive');

  /// JSONから復元
  factory WeeklyQuest.fromJson(Map<String, dynamic> json) {
    return WeeklyQuest(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      targetCategory: json['targetCategory'] as String,
      budgetLimit: json['budgetLimit'] as int,
      currentAvgSpend: json['currentAvgSpend'] as int,
      difficulty: QuestDifficulty.values.firstWhere(
        (d) => d.name == json['difficulty'],
        orElse: () => QuestDifficulty.medium,
      ),
      generatedAt: DateTime.parse(json['generatedAt'] as String),
      weekStart: DateTime.parse(json['weekStart'] as String),
      templateId: json['templateId'] as String,
    );
  }

  /// JSONに変換
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'targetCategory': targetCategory,
      'budgetLimit': budgetLimit,
      'currentAvgSpend': currentAvgSpend,
      'difficulty': difficulty.name,
      'generatedAt': generatedAt.toIso8601String(),
      'weekStart': weekStart.toIso8601String(),
      'templateId': templateId,
    };
  }

  /// 削減率（%） — currentAvgSpend に対する budgetLimit の差
  double get reductionPercent {
    if (currentAvgSpend <= 0) return 0;
    return ((currentAvgSpend - budgetLimit) / currentAvgSpend * 100)
        .clamp(0, 100);
  }

  /// 削減額（円）
  int get reductionAmount => (currentAvgSpend - budgetLimit).clamp(0, 999999);

  /// クエストの簡単なサマリ文字列
  String get summary => '$title（¥$currentAvgSpend→¥$budgetLimit）';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeeklyQuest &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'WeeklyQuest(id: $id, title: $title, category: $targetCategory, '
      'limit: ¥$budgetLimit, difficulty: ${difficulty.name})';
}

/// クエスト難易度
///
/// 直近支出からの削減率に基づく:
/// - easy:   削減率 0〜15%（緩やかな挑戦）
/// - medium: 削減率 15〜25%（標準的な挑戦）
/// - hard:   削減率 25%以上（厳しい挑戦）
enum QuestDifficulty {
  easy,
  medium,
  hard;

  /// 削減率から難易度を判定
  static QuestDifficulty fromReductionPercent(double percent) {
    if (percent >= 25) return hard;
    if (percent >= 15) return medium;
    return easy;
  }

  /// 表示用ラベル（日本語）
  String get label {
    switch (this) {
      case QuestDifficulty.easy:
        return '易';
      case QuestDifficulty.medium:
        return '中';
      case QuestDifficulty.hard:
        return '難';
    }
  }
}
