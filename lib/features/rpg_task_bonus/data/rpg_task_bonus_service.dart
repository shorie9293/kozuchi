import 'dart:convert';
import 'dart:io';

import 'package:kozuchi/features/rpg_task_bonus/data/rpg_task_bonus_log_repository.dart';

/// rpg-taskの敵討伐イベントを読み取り、kozuchi側でボーナスEXPを付与するサービス
///
/// rpg-taskが共有ストレージに書き出した enemy_defeated イベントを読み取り、
/// クエストランクに応じたボーナスEXPを計算する。1日3回までの制限付き。
///
/// 共有ファイルパス: /data/local/tmp/takamagahara_shared/rpg_enemy_defeat_events.json
class RpgTaskBonusService {
  /// 共有ストレージのファイルパス
  final String filePath;

  /// 1日あたりの最大ボーナス回数
  static const int maxDailyBonuses = 3;

  /// ボーナスEXPログリポジトリ（日次カウント・履歴管理用）
  final RpgTaskBonusLogRepository logRepo;

  const RpgTaskBonusService({
    this.filePath =
        '/data/local/tmp/takamagahara_shared/rpg_enemy_defeat_events.json',
    this.logRepo = const RpgTaskBonusLogRepository(),
  });

  /// 共有ファイルを読み取り、条件を満たす場合にボーナスEXPを返す
  ///
  /// 戻り値:
  /// - ファイルが存在しない場合 → null
  /// - 1日の上限（3回）に達している場合 → null
  /// - ファイルが存在し、上限未達の場合 → RpgTaskBonusResult
  ///
  /// 成功時はファイルを削除し、ログに記録する。
  Future<RpgTaskBonusResult?> checkAndConsume() async {
    // 1日の上限チェック
    final todayCount = await logRepo.getTodayCount();
    if (todayCount >= maxDailyBonuses) return null;

    final file = File(filePath);
    if (!await file.exists()) return null;

    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;

      final event = json['event'] as String?;
      if (event != 'enemy_defeated') return null;

      final taskTitle = json['taskTitle'] as String? ?? '不明なクエスト';
      final questRank = json['questRank'] as String? ?? 'B';
      final baseExp = json['baseExp'] as int? ?? 0;

      // ランク別ボーナスEXP
      final bonusExp = _bonusExpForRank(questRank);

      if (bonusExp <= 0) {
        // 無効なランクの場合もファイルは消費する
        await file.delete();
        return null;
      }

      // ファイルを消費（削除）して重複付与を防ぐ
      await file.delete();

      // ログに記録
      await logRepo.recordBonus(
        taskTitle: taskTitle,
        questRank: questRank,
        bonusExp: bonusExp,
        baseExp: baseExp,
      );

      return RpgTaskBonusResult(
        taskTitle: taskTitle,
        questRank: questRank,
        bonusExp: bonusExp,
        baseExp: baseExp,
      );
    } catch (_) {
      return null;
    }
  }

  /// クエストランクに応じたボーナスEXPを返す
  static int bonusExpForRank(String questRank) => _bonusExpForRank(questRank);

  static int _bonusExpForRank(String questRank) {
    switch (questRank.toUpperCase()) {
      case 'S':
        return 50;
      case 'A':
        return 30;
      case 'B':
        return 15;
      default:
        return 0;
    }
  }

  /// 本日の残りボーナス回数を返す
  Future<int> getRemainingBonusesToday() async {
    return logRepo.getRemainingBonusesToday(maxDaily: maxDailyBonuses);
  }
}

/// rpg-task敵討伐ボーナスの結果
class RpgTaskBonusResult {
  final String taskTitle;
  final String questRank;
  final int bonusExp;
  final int baseExp;

  const RpgTaskBonusResult({
    required this.taskTitle,
    required this.questRank,
    required this.bonusExp,
    this.baseExp = 0,
  });
}
