import 'dart:convert';
import 'dart:io';

import 'package:kozuchi/core/infrastructure/shared_file_store.dart';
import 'package:kozuchi/core/logging/app_logger.dart';
import 'package:kozuchi/features/rpg_task_bonus/data/rpg_task_bonus_log_repository.dart';

/// rpg-taskの敵討伐イベントを読み取り、kozuchi側でボーナスEXPを付与するサービス
///
/// rpg-taskが共有ストレージに書き出した enemy_defeated イベントを読み取り、
/// クエストランクに応じたボーナスEXPを計算する。1日3回までの制限付き。
///
/// 契約名: [SharedCrossAppFiles.rpgEnemyDefeatJson]
///
/// 保存先の解決:
/// - [filePath] が非 null → そのパスを直に読む（試練・デスクトップ）
/// - [filePath] が null → [SharedFileStore.instance]（Android は SAF）
class RpgTaskBonusService {
  /// 共有ストレージのファイルパス。null なら [SharedFileStore.instance] を使う。
  final String? filePath;

  /// 1日あたりの最大ボーナス回数
  static const int maxDailyBonuses = 3;

  /// ボーナスEXPログリポジトリ（日次カウント・履歴管理用）
  final RpgTaskBonusLogRepository logRepo;

  const RpgTaskBonusService({
    this.filePath,
    this.logRepo = const RpgTaskBonusLogRepository(),
  });

  /// 読取元ストア。filePath 指定時はその親ディレクトリを直に読む（後方互換）。
  ISharedFileStore get _store => filePath != null
      ? FileSharedFileStore(File(filePath!).parent)
      : SharedFileStore.instance;

  /// 入力ファイル名。共有ストレージ経由のときは契約名を使う。
  String get _fileName {
    if (filePath == null) return SharedCrossAppFiles.rpgEnemyDefeatJson;
    return filePath!.split('/').last;
  }

  /// 共有ファイルを読み取り、条件を満たす場合にボーナスEXPを返す
  ///
  /// 戻り値:
  /// - ファイルが存在しない場合 → null
  /// - 1日の上限（3回）に達している場合 → null
  /// - ファイルが存在し、上限未達の場合 → RpgTaskBonusResult
  ///
  /// 成功時はファイルを削除し、ログに記録する。
  /// 共有ストレージ自体の失敗は [SharedStorageException] として上位へ伝える。
  Future<RpgTaskBonusResult?> checkAndConsume() async {
    // 1日の上限チェック
    final todayCount = await logRepo.getTodayCount();
    if (todayCount >= maxDailyBonuses) return null;

    final String? content;
    try {
      content = await _store.readString(_fileName);
    } on SharedStorageException catch (e) {
      appLog.warn('[RpgTaskBonusService] 共有ストレージ読取失敗', e);
      rethrow;
    }
    // ファイルが無い＝未連携（正常系）
    if (content == null) return null;

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(content) as Map<String, dynamic>;
    } on FormatException {
      return null;
    }

    final event = json['event'] as String?;
    if (event != 'enemy_defeated') return null;

    final taskTitle = json['taskTitle'] as String? ?? '不明なクエスト';
    final questRank = json['questRank'] as String? ?? 'B';
    final baseExp = json['baseExp'] as int? ?? 0;

    // ランク別ボーナスEXP
    final bonusExp = _bonusExpForRank(questRank);

    if (bonusExp <= 0) {
      // 無効なランクの場合もファイルは消費する
      await _consume();
      return null;
    }

    // ファイルを消費（削除）して重複付与を防ぐ
    await _consume();

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
  }

  /// 消費（削除）。失敗は [SharedStorageException] として上位へ伝える。
  Future<void> _consume() async {
    try {
      await _store.delete(_fileName);
    } on SharedStorageException catch (e) {
      appLog.warn('[RpgTaskBonusService] 共有ストレージ削除失敗', e);
      rethrow;
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
