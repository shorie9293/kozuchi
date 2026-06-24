/// 貯蓄目標（Goal）のデータモデル
///
/// kozuchiサーバーの /api/goals エンドポイントと対応。
class Goal {
  final String id;
  final String userId;
  final String title;
  final int targetAmount;
  final String? deadline; // YYYY-MM-DD or null
  final int currentAmount;
  final String status; // 'active' | 'completed' | 'cancelled'
  final double? progressPercent; // 0.0–100.0, null when target_amount=0
  final DateTime createdAt;
  final DateTime updatedAt;

  const Goal({
    required this.id,
    required this.userId,
    required this.title,
    required this.targetAmount,
    this.deadline,
    required this.currentAmount,
    required this.status,
    this.progressPercent,
    required this.createdAt,
    required this.updatedAt,
  });

  /// API の JSON レスポンスから Goal を生成
  factory Goal.fromJson(Map<String, dynamic> json) {
    return Goal(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      targetAmount: json['target_amount'] as int,
      deadline: json['deadline'] as String?,
      currentAmount: json['current_amount'] as int,
      status: json['status'] as String,
      progressPercent: (json['progress_percent'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// 完了しているか
  bool get isCompleted => status == 'completed';

  /// キャンセルされているか
  bool get isCancelled => status == 'cancelled';

  /// アクティブか
  bool get isActive => status == 'active';

  /// 表示用の進捗率（0.0–1.0）
  double get progressRatio =>
      (progressPercent ?? 0.0) / 100.0;

  /// 期限切れか（deadline が過去日付の場合）
  bool get isOverdue {
    final dl = deadline;
    if (dl == null) return false;
    final parsed = DateTime.tryParse(dl);
    if (parsed == null) return false;
    return parsed.isBefore(DateTime.now()) && status == 'active';
  }

  /// 表示用の金額フォーマット（例: "¥50,000"）
  String formatAmount(int amount) {
    if (amount == 0) return '¥0';
    final negative = amount < 0;
    final absStr = amount.abs().toString();
    final buffer = StringBuffer();
    if (negative) buffer.write('-');
    buffer.write('¥');
    for (int i = 0; i < absStr.length; i++) {
      if (i > 0 && (absStr.length - i) % 3 == 0) buffer.write(',');
      buffer.write(absStr[i]);
    }
    return buffer.toString();
  }
}
