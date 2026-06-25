import 'package:kozuchi/domain/models/achievement_api_model.dart';

/// 実績チェックAPIのリクエストモデル
///
/// POST /api/achievements/check に送信するユーザー状態データ。
class AchievementCheckRequest {
  final String userId;
  final int offeringCount;
  final int totalDonation;
  final int streakDays;
  final int categoriesUsed;
  final int satoriLevel;
  final int guardiansTried;
  final int receiptCount;
  final int budgetSetCount;
  final int budgetPerfectDays;

  const AchievementCheckRequest({
    required this.userId,
    this.offeringCount = 0,
    this.totalDonation = 0,
    this.streakDays = 0,
    this.categoriesUsed = 0,
    this.satoriLevel = 0,
    this.guardiansTried = 0,
    this.receiptCount = 0,
    this.budgetSetCount = 0,
    this.budgetPerfectDays = 0,
  });

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'offering_count': offeringCount,
        'total_donation': totalDonation,
        'streak_days': streakDays,
        'categories_used': categoriesUsed,
        'satori_level': satoriLevel,
        'guardians_tried': guardiansTried,
        'receipt_count': receiptCount,
        'budget_set_count': budgetSetCount,
        'budget_perfect_days': budgetPerfectDays,
      };
}

/// 実績チェックAPIのレスポンスモデル
class AchievementCheckResponse {
  final List<AchievementApiModel> newlyUnlocked;
  final int alreadyUnlockedCount;
  final int totalAchievements;

  const AchievementCheckResponse({
    required this.newlyUnlocked,
    required this.alreadyUnlockedCount,
    required this.totalAchievements,
  });

  factory AchievementCheckResponse.fromJson(Map<String, dynamic> json) {
    final unlockedList = json['newly_unlocked'] as List<dynamic>? ?? [];
    return AchievementCheckResponse(
      newlyUnlocked: unlockedList
          .map((e) => AchievementApiModel.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList(),
      alreadyUnlockedCount: json['already_unlocked_count'] as int? ?? 0,
      totalAchievements: json['total_achievements'] as int? ?? 0,
    );
  }
}
