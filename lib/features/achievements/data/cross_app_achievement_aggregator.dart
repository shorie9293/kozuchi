import 'dart:convert';
import 'dart:io';

import 'package:kozuchi/core/infrastructure/shared_file_store.dart';
import 'package:kozuchi/core/logging/app_logger.dart';

/// クロスアプリ実績集計サービス
///
/// 共有ストレージ（現世をまたぐ受け渡しフォルダ）から
/// rpg-task（敵討伐）・tsundoku-quest（読了）のイベントデータを読み取り、
/// kozuchi自身の金獲得量と合わせて「三現世制覇」等の相互実績判定に用いる。
///
/// 保存先の解決:
/// - [basePath] が非 null → そのディレクトリを直に読む（試練・デスクトップ）
/// - [basePath] が null → [SharedFileStore.instance]（Android は SAF）
class CrossAppAchievementAggregator {
  /// 共有ストレージのベースパス。null なら [SharedFileStore.instance] を使う。
  final String? basePath;

  const CrossAppAchievementAggregator({this.basePath});

  /// 読み取り元。basePath 指定時はそのディレクトリ、未指定時は共有ストア。
  ISharedFileStore get _store => basePath != null
      ? FileSharedFileStore(Directory(basePath!))
      : SharedFileStore.instance;

  // ── 個別カウンター ──

  /// 敵討伐回数を共有ストレージから集計する
  ///
  /// JSONL 形式の `rpg_enemy_defeat_events.jsonl` から
  /// `event == "enemy_defeated"` の行数を数える。
  Future<int> countEnemyDefeats() async {
    return _countJsonlEvents(
      SharedCrossAppFiles.rpgEnemyDefeatJsonl,
      'enemy_defeated',
    );
  }

  /// 読了回数を共有ストレージから集計する
  ///
  /// 単一JSONファイル (`tsundoku_book_completed.json`) と
  /// JSONL ファイル (`tsundoku_reward_events.jsonl`) の両方を確認し、
  /// `event == "book_completed"` または `event_type == "book_completed"` の数を数える。
  /// 単一JSON にイベントがあれば +1、JSONL の行数も加算する（重複は backend 側で対処）。
  Future<int> countBooksRead() async {
    int count = 0;

    // 単一JSONファイルの確認（無い＝未連携なので正常系）
    final content = await _read(SharedCrossAppFiles.tsundokuBookCompleted);
    if (content != null) {
      try {
        final json = jsonDecode(content) as Map<String, dynamic>;
        if (json['event'] == 'book_completed') {
          count += 1;
        }
      } on FormatException {
        // 壊れた JSON はスキップ（共有相手の書込途中など）
      }
    }

    // JSONL ファイルの確認
    count += await _countJsonlEvents(
      SharedCrossAppFiles.tsundokuRewardEvents,
      'book_completed',
      fieldName: 'event_type',
    );

    return count;
  }

  /// 金獲得量（kozuchi 側で追跡）
  ///
  /// この値は kozuchi の内部状態から渡される。
  /// 集計サービスはストレージ読み取りのみ担当するため、
  /// このメソッドは [goldEarned] パラメータをそのまま返すだけのプレースホルダ。
  int countGoldEarned(int goldEarned) => goldEarned;

  // ── 複合チェック ──

  /// 「三現世制覇」の条件を満たしているかを判定する
  ///
  /// 条件:
  /// - 敵討伐 10体以上
  /// - 読了 5冊以上
  /// - 金獲得 1000以上（kozuchi）
  Future<ThreeWorldsStatus> checkThreeWorldsConquest({
    required int goldEarned,
  }) async {
    final enemiesDefeated = await countEnemyDefeats();
    final booksRead = await countBooksRead();

    final conditions = ThreeWorldsConditions(
      enemiesDefeated: enemiesDefeated,
      booksRead: booksRead,
      goldEarned: goldEarned,
    );

    return ThreeWorldsStatus(
      conditions: conditions,
      allMet: enemiesDefeated >= 10 && booksRead >= 5 && goldEarned >= 1000,
    );
  }

  // ── 内部ヘルパー ──

  /// 共有ストアから 1 ファイル読む。
  ///
  /// 存在しなければ null（未連携＝正常系）。読取そのものの失敗は
  /// [SharedStorageException] として上位へ伝える（無音に捨てない）。
  Future<String?> _read(String fileName) async {
    try {
      return await _store.readString(fileName);
    } on SharedStorageException catch (e) {
      appLog.warn('[CrossAppAchievementAggregator] 共有ストレージ読取失敗', e);
      rethrow;
    }
  }

  /// JSONL ファイルから特定イベントの出現回数を数える
  ///
  /// [fileName] の各行を JSON としてパースし、
  /// `json[fieldName] == eventType` に一致する行数を返す。
  /// ファイルが存在しない（未連携）なら 0。壊れた行はスキップする。
  Future<int> _countJsonlEvents(
    String fileName,
    String eventType, {
    String fieldName = 'event',
  }) async {
    final content = await _read(fileName);
    if (content == null) return 0;

    int count = 0;
    for (final line in const LineSplitter().convert(content)) {
      if (line.trim().isEmpty) continue;
      try {
        final json = jsonDecode(line) as Map<String, dynamic>;
        if (json[fieldName] == eventType) {
          count++;
        }
      } on FormatException {
        // 不正な行はスキップ
      }
    }
    return count;
  }
}

/// 三現世制覇の条件値
class ThreeWorldsConditions {
  final int enemiesDefeated;
  final int booksRead;
  final int goldEarned;

  const ThreeWorldsConditions({
    required this.enemiesDefeated,
    required this.booksRead,
    required this.goldEarned,
  });
}

/// 三現世制覇の判定結果
class ThreeWorldsStatus {
  final ThreeWorldsConditions conditions;
  final bool allMet;

  const ThreeWorldsStatus({
    required this.conditions,
    required this.allMet,
  });

  /// 未達成の条件の説明を返す
  List<String> get unmetReasons {
    final reasons = <String>[];
    if (conditions.enemiesDefeated < 10) {
      reasons.add(
        '敵討伐: ${conditions.enemiesDefeated}/10',
      );
    }
    if (conditions.booksRead < 5) {
      reasons.add(
        '読了: ${conditions.booksRead}/5',
      );
    }
    if (conditions.goldEarned < 1000) {
      reasons.add(
        '金獲得: ${conditions.goldEarned}/1000',
      );
    }
    return reasons;
  }
}
