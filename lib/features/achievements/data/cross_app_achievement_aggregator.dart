import 'dart:convert';
import 'dart:io';

/// クロスアプリ実績集計サービス
///
/// 共有ストレージ (`/data/local/tmp/takamagahara_shared/`) から
/// rpg-task（敵討伐）・tsundoku-quest（読了）のイベントデータを読み取り、
/// kozuchi自身の金獲得量と合わせて「三現世制覇」等の相互実績判定に用いる。
class CrossAppAchievementAggregator {
  /// 共有ストレージのベースパス
  final String basePath;

  const CrossAppAchievementAggregator({
    this.basePath = '/data/local/tmp/takamagahara_shared',
  });

  /// rpg-task の敵討伐イベントファイルのパス
  String get _enemyDefeatPath => '$basePath/rpg_enemy_defeat_events.jsonl';

  /// tsundoku-quest の読了イベントファイルのパス
  String get _bookCompletedPath =>
      '$basePath/tsundoku_book_completed.json';

  /// tsundoku-quest の報酬イベント（JSONL）のパス
  String get _rewardEventsPath =>
      '$basePath/tsundoku_reward_events.jsonl';

  // ── 個別カウンター ──

  /// 敵討伐回数を共有ストレージから集計する
  ///
  /// JSONL 形式の `rpg_enemy_defeat_events.jsonl` から
  /// `event == "enemy_defeated"` の行数を数える。
  Future<int> countEnemyDefeats() async {
    return _countJsonlEvents(_enemyDefeatPath, 'enemy_defeated');
  }

  /// 読了回数を共有ストレージから集計する
  ///
  /// 単一JSONファイル (`tsundoku_book_completed.json`) と
  /// JSONL ファイル (`tsundoku_reward_events.jsonl`) の両方を確認し、
  /// `event == "book_completed"` または `event_type == "book_completed"` の数を数える。
  /// 単一JSON にイベントがあれば +1、JSONL の行数も加算する（重複は backend 側で対処）。
  Future<int> countBooksRead() async {
    int count = 0;

    // 単一JSONファイルの確認
    final singleFile = File(_bookCompletedPath);
    if (await singleFile.exists()) {
      try {
        final content = await singleFile.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        if (json['event'] == 'book_completed') {
          count += 1;
        }
      } catch (_) {
        // 読み取りエラーは無視
      }
    }

    // JSONL ファイルの確認
    count += await _countJsonlEvents(_rewardEventsPath, 'book_completed',
        fieldName: 'event_type');

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
      allMet: enemiesDefeated >= 10 &&
          booksRead >= 5 &&
          goldEarned >= 1000,
    );
  }

  // ── 内部ヘルパー ──

  /// JSONL ファイルから特定イベントの出現回数を数える
  ///
  /// [filePath] の各行を JSON としてパースし、
  /// `json[fieldName] == eventType` に一致する行数を返す。
  /// ファイルが存在しない or 読み取りエラー時は 0 を返す。
  Future<int> _countJsonlEvents(
    String filePath,
    String eventType, {
    String fieldName = 'event',
  }) async {
    final file = File(filePath);
    if (!await file.exists()) return 0;

    try {
      final lines = await file.readAsLines();
      int count = 0;
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        try {
          final json = jsonDecode(line) as Map<String, dynamic>;
          if (json[fieldName] == eventType) {
            count++;
          }
        } catch (_) {
          // 不正な行はスキップ
        }
      }
      return count;
    } catch (_) {
      return 0;
    }
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
