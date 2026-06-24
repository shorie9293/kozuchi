/// 復帰ミッション
///
/// ストリーク途絶＋飢餓地帯発動時に発行される救済クエスト。
/// 完了すると飢餓地帯から即時脱出できる。
class ReturnMission {
  /// ミッションID
  final String id;

  /// ミッションタイトル
  final String title;

  /// ミッション説明
  final String description;

  /// 達成に必要な目標値（例: 支出額、レシート枚数）
  final int targetValue;

  /// 現在の進捗値
  final int currentProgress;

  /// 完了したか
  final bool isCompleted;

  /// 発行日時（null = 未発行）
  final DateTime? issuedAt;

  /// 完了日時
  final DateTime? completedAt;

  const ReturnMission({
    required this.id,
    required this.title,
    required this.description,
    required this.targetValue,
    this.currentProgress = 0,
    this.isCompleted = false,
    required this.issuedAt,
    this.completedAt,
  });

  /// 未発行（ミッションなし）の状態
  factory ReturnMission.none() => const ReturnMission(
        id: '',
        title: '',
        description: '',
        targetValue: 0,
      );

  /// 途絶時のストリーク日数に基づいて復帰ミッションを生成する。
  ///
  /// [brokenStreakDays] が長いほど難易度の高いミッションになる。
  factory ReturnMission.generate(int brokenStreakDays) {
    if (brokenStreakDays >= 30) {
      return ReturnMission(
        id: _generateId(),
        title: '大いなる復帰',
        description: '¥5,000以上の支出を記録し、財政の流れを取り戻せ。',
        targetValue: 5000,
        issuedAt: DateTime.now(),
      );
    }
    if (brokenStreakDays >= 14) {
      return ReturnMission(
        id: _generateId(),
        title: '財政の再起動',
        description: '¥2,000以上の支出を記録せよ。',
        targetValue: 2000,
        issuedAt: DateTime.now(),
      );
    }
    if (brokenStreakDays >= 7) {
      return ReturnMission(
        id: _generateId(),
        title: '小さな再出発',
        description: '¥500以上の支出を記録し、活動を再開せよ。',
        targetValue: 500,
        issuedAt: DateTime.now(),
      );
    }
    // 7日未満：軽いタスク
    return ReturnMission(
      id: _generateId(),
      title: '気軽な復帰',
      description: '¥100以上の支出を記録せよ。',
      targetValue: 100,
      issuedAt: DateTime.now(),
    );
  }

  /// 進捗を更新する
  ReturnMission updateProgress(int newProgress) {
    if (isCompleted) return this;
    final clamped = newProgress.clamp(0, targetValue);
    return ReturnMission(
      id: id,
      title: title,
      description: description,
      targetValue: targetValue,
      currentProgress: clamped,
      isCompleted: clamped >= targetValue,
      issuedAt: issuedAt,
      completedAt: clamped >= targetValue ? DateTime.now() : completedAt,
    );
  }

  /// 完了としてマークする
  ReturnMission markCompleted() {
    return ReturnMission(
      id: id,
      title: title,
      description: description,
      targetValue: targetValue,
      currentProgress: targetValue,
      isCompleted: true,
      issuedAt: issuedAt,
      completedAt: DateTime.now(),
    );
  }

  static String _generateId() {
    final now = DateTime.now();
    return 'rm_${now.millisecondsSinceEpoch}';
  }

  /// JSONから復元
  factory ReturnMission.fromJson(Map<String, dynamic> json) {
    return ReturnMission(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      targetValue: json['targetValue'] as int? ?? 0,
      currentProgress: json['currentProgress'] as int? ?? 0,
      isCompleted: json['isCompleted'] as bool? ?? false,
      issuedAt: json['issuedAt'] != null
          ? DateTime.tryParse(json['issuedAt'] as String)
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
    );
  }

  /// JSONに変換
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'targetValue': targetValue,
      'currentProgress': currentProgress,
      'isCompleted': isCompleted,
      'issuedAt': issuedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }
}
