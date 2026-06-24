import 'package:kozuchi/features/rpg_task_bonus/data/rpg_task_bonus_log_repository.dart';
import 'package:kozuchi/features/rpg_task_bonus/data/rpg_task_bonus_service.dart';
import 'package:kozuchi/domain/models/gold_luck_buff.dart';
import 'package:kozuchi/domain/models/player_model.dart';

/// Aggregates collaboration event data from rpg-task and tsundoku integrations
/// for the Collaboration Dashboard.
///
/// Reads from:
/// - [RpgTaskBonusLogRepository] for bonus EXP event history
/// - [RpgTaskBonusService] for daily bonus status
/// - [PlayerModel.goldLuckBuff] for active tsundoku gold buff
class CollaborationStatsService {
  final RpgTaskBonusLogRepository _bonusLogRepo;
  final RpgTaskBonusService _bonusService;

  const CollaborationStatsService({
    RpgTaskBonusLogRepository bonusLogRepo =
        const RpgTaskBonusLogRepository(),
    RpgTaskBonusService bonusService = const RpgTaskBonusService(),
  })  : _bonusLogRepo = bonusLogRepo,
        _bonusService = bonusService;

  /// Loads the complete collaboration stats snapshot.
  Future<CollaborationStats> loadStats(PlayerModel player) async {
    final bonusLog = await _bonusLogRepo.getLog();
    final remainingBonuses =
        await _bonusService.getRemainingBonusesToday();
    final totalBonusExp = bonusLog.fold<int>(
      0,
      (sum, entry) => sum + ((entry['bonusExp'] as num?)?.toInt() ?? 0),
    );
    final buff = player.goldLuckBuff;
    final hasActiveBuff = buff?.isActive == true;

    return CollaborationStats(
      recentBonusEvents: bonusLog,
      totalBonusExpAwarded: totalBonusExp,
      remainingDailyBonuses: remainingBonuses,
      maxDailyBonuses: RpgTaskBonusService.maxDailyBonuses,
      totalSynergyEvents: bonusLog.length + (hasActiveBuff ? 1 : 0),
      hasActiveGoldBuff: hasActiveBuff,
      activeGoldBuff: hasActiveBuff ? buff : null,
    );
  }
}

/// Immutable snapshot of all collaboration stats for the dashboard.
class CollaborationStats {
  final List<Map<String, dynamic>> recentBonusEvents;
  final int totalBonusExpAwarded;
  final int remainingDailyBonuses;
  final int maxDailyBonuses;
  final int totalSynergyEvents;
  final bool hasActiveGoldBuff;
  final GoldLuckBuff? activeGoldBuff;

  const CollaborationStats({
    required this.recentBonusEvents,
    required this.totalBonusExpAwarded,
    required this.remainingDailyBonuses,
    required this.maxDailyBonuses,
    required this.totalSynergyEvents,
    required this.hasActiveGoldBuff,
    this.activeGoldBuff,
  });

  /// Number of bonus EXP events displayed.
  int get bonusEventCount => recentBonusEvents.length;

  /// Daily bonus usage fraction (0.0 - 1.0).
  double get dailyBonusUsage {
    final used = maxDailyBonuses - remainingDailyBonuses;
    if (maxDailyBonuses <= 0) return 0.0;
    return used / maxDailyBonuses;
  }
}
