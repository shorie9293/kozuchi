/// 実績APIレスポンス用モデル
///
/// GET /api/achievements のレスポンスJSONをパースする。
/// 実績の定義情報 + ユーザー別の解除状態・進捗を含む。
class AchievementApiModel {
  final int id;
  final String key;
  final String title;
  final String description;
  final String criteriaType;
  final int criteriaValue;
  final String icon;
  final int sortOrder;
  final bool unlocked;
  final String? unlockedAt;
  final AchievementProgress? progress;

  const AchievementApiModel({
    required this.id,
    required this.key,
    required this.title,
    required this.description,
    required this.criteriaType,
    required this.criteriaValue,
    required this.icon,
    required this.sortOrder,
    required this.unlocked,
    this.unlockedAt,
    this.progress,
  });

  factory AchievementApiModel.fromJson(Map<String, dynamic> json) {
    return AchievementApiModel(
      id: json['id'] as int,
      key: json['key'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      criteriaType: json['criteria_type'] as String? ?? '',
      criteriaValue: json['criteria_value'] as int? ?? 0,
      icon: json['icon'] as String? ?? '🏆',
      sortOrder: json['sort_order'] as int? ?? 0,
      unlocked: json['unlocked'] as bool? ?? false,
      unlockedAt: json['unlocked_at'] as String?,
      progress: json['progress'] != null
          ? AchievementProgress.fromJson(
              Map<String, dynamic>.from(json['progress'] as Map))
          : null,
    );
  }

  /// 進捗表示用テキスト
  /// 例: "¥50,000 / ¥100,000" または "25/30日"
  String? get progressText {
    if (unlocked || progress == null) return null;
    final c = progress!.current;
    final t = progress!.target;
    // criteria_type に応じて表示形式を変える
    switch (criteriaType) {
      case 'total_donation':
        return '¥${_formatNumber(c)} / ¥${_formatNumber(t)}';
      case 'streak_days':
        return '$c / $t日';
      case 'offering_count':
        return '$c / $t回';
      default:
        return '$c / $t';
    }
  }

  /// 進捗率 (0.0-1.0)
  double? get progressFraction {
    if (unlocked || progress == null) return null;
    if (progress!.target <= 0) return 1.0;
    return (progress!.current / progress!.target).clamp(0.0, 1.0);
  }

  static String _formatNumber(int n) {
    if (n >= 10000) {
      return '${(n ~/ 10000)}万';
    }
    return n.toString();
  }
}

/// 実績の進捗情報
class AchievementProgress {
  final int current;
  final int target;
  final double pct;

  const AchievementProgress({
    required this.current,
    required this.target,
    required this.pct,
  });

  factory AchievementProgress.fromJson(Map<String, dynamic> json) {
    return AchievementProgress(
      current: json['current'] as int? ?? 0,
      target: json['target'] as int? ?? 0,
      pct: (json['pct'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
