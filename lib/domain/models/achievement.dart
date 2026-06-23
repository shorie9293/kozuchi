/// 称号モデル
///
/// 目標達成時に獲得できる称号（タイトル）を表す。
/// SharedPreferences で永続化するための JSON シリアライズに対応。
class Achievement {
  /// 称号の一意識別子
  final String id;

  /// 称号名（例: 「初めての貯金」「万元突破」「節約マスター」）
  final String title;

  /// 称号の説明文
  final String description;

  /// 獲得日時
  final DateTime earnedAt;

  /// 関連する目標ID（どの目標達成で獲得したか）
  final String? goalId;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.earnedAt,
    this.goalId,
  });

  /// 目標達成から称号を自動生成するファクトリ
  ///
  /// 目標額に応じて称号のグレードが変わる。
  factory Achievement.forGoal(dynamic goal) {
    final targetAmount = (goal.targetAmount as int?) ?? 0;
    final title = goal.title as String? ?? '';

    String achievementTitle;
    String description;

    if (targetAmount <= 0) {
      // 習慣系目標
      achievementTitle = '習慣の達人';
      description = '「$title」を見事達成！継続は力なり。';
    } else if (targetAmount < 10000) {
      achievementTitle = '小さな一歩';
      description = '「$title」を達成。千里の道も一歩から。';
    } else if (targetAmount < 100000) {
      achievementTitle = '蓄財の心得';
      description = '「$title」を見事達成。着実な前進。';
    } else if (targetAmount < 1000000) {
      achievementTitle = '百万長者への道';
      description = '「$title」を達成。大台への第一歩。';
    } else {
      achievementTitle = '伝説の蓄財王';
      description = '「$title」を達成。百万を超える大願成就。';
    }

    return Achievement(
      id: 'achv_${DateTime.now().millisecondsSinceEpoch}_${targetAmount}',
      title: achievementTitle,
      description: description,
      earnedAt: DateTime.now(),
      goalId: goal.id as String?,
    );
  }

  /// JSONから復元
  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      earnedAt: DateTime.tryParse(json['earnedAt'] as String? ?? '') ??
          DateTime.now(),
      goalId: json['goalId'] as String?,
    );
  }

  /// JSONに変換
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'earnedAt': earnedAt.toIso8601String(),
      'goalId': goalId,
    };
  }
}
