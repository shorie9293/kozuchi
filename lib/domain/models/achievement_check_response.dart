import 'package:kozuchi/domain/models/achievement_api_model.dart';

/// POST /api/achievements/check のレスポンスモデル
///
/// [newlyUnlocked] には今回新たに解除された実績のリストが入る。
/// 既に解除済みの実績は含まれない（冪等）。
class CheckResponse {
  final List<AchievementApiModel> newlyUnlocked;
  final int alreadyUnlockedCount;
  final int totalAchievements;

  const CheckResponse({
    required this.newlyUnlocked,
    required this.alreadyUnlockedCount,
    required this.totalAchievements,
  });

  factory CheckResponse.fromJson(Map<String, dynamic> json) {
    final unlockedList = (json['newly_unlocked'] as List<dynamic>?)
            ?.map((e) => AchievementApiModel.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList() ??
        [];

    return CheckResponse(
      newlyUnlocked: unlockedList,
      alreadyUnlockedCount: json['already_unlocked_count'] as int? ?? 0,
      totalAchievements: json['total_achievements'] as int? ?? 0,
    );
  }

  /// 新規解除があったかどうか
  bool get hasNewUnlocks => newlyUnlocked.isNotEmpty;
}
