import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kozuchi/features/achievements/data/cross_app_achievement_aggregator.dart';
import 'package:kozuchi/features/rpg_task_bonus/data/rpg_task_bonus_service.dart';

/// rpg-task ⇄ kozuchi 討伐イベント共有契約 v1 の回帰試練。
///
/// rpg-task は共有ストレージ `/data/local/tmp/takamagahara_shared/` へ
/// 同一スキーマのイベントを「デュアルライト」する:
///   A. `rpg_enemy_defeat_events.json`  — 直近1件の単一JSON
///      （読取: [RpgTaskBonusService]、消費時に削除）
///   B. `rpg_enemy_defeat_events.jsonl` — 追記専用・1行1コンパクトJSON
///      （読取: [CrossAppAchievementAggregator]、行数カウント）
///
/// イベントスキーマ（両者共通）:
/// `{event: 'enemy_defeated', taskTitle: String, questRank: 'S'|'A'|'B',
///   baseExp: int, timestamp: ISO8601 UTC}`
void main() {
  late Directory tempDir;
  late String singleJsonPath;
  late String jsonlPath;
  late CrossAppAchievementAggregator aggregator;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('enemy_defeat_contract_');
    singleJsonPath = '${tempDir.path}/rpg_enemy_defeat_events.json';
    jsonlPath = '${tempDir.path}/rpg_enemy_defeat_events.jsonl';
    aggregator = CrossAppAchievementAggregator(basePath: tempDir.path);
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// rpg-task が書き出すのと同一スキーマのイベントを組み立てる
  Map<String, dynamic> defeatEvent({
    required String taskTitle,
    required String questRank,
    required int baseExp,
    String timestamp = '2026-10-23T01:23:45.000Z',
  }) =>
      <String, dynamic>{
        'event': 'enemy_defeated',
        'taskTitle': taskTitle,
        'questRank': questRank,
        'baseExp': baseExp,
        'timestamp': timestamp,
      };

  /// 契約 A: 単一JSON を書き出す
  Future<void> writeSingleJson(Map<String, dynamic> event) =>
      File(singleJsonPath).writeAsString(jsonEncode(event));

  /// 契約 B: JSONL を書き出す（1行1コンパクトJSON・追記専用の想定）
  Future<void> writeJsonl(List<Map<String, dynamic>> events) =>
      File(jsonlPath).writeAsString(
        events.map(jsonEncode).join('\n'),
      );

  group('契約A: 単一JSON → RpgTaskBonusService', () {
    test('rpg-task 形式の単一JSONを読み、契約どおりの値を返しファイルを消費する', () async {
      final event = defeatEvent(
        taskTitle: '魔王討伐',
        questRank: 'A',
        baseExp: 150,
      );
      await writeSingleJson(event);

      final service = RpgTaskBonusService(filePath: singleJsonPath);
      final result = await service.checkAndConsume();

      expect(result, isNotNull);
      expect(result!.taskTitle, '魔王討伐');
      expect(result.questRank, 'A');
      expect(result.baseExp, 150);
      expect(result.bonusExp, greaterThan(0));
      expect(result.bonusExp, RpgTaskBonusService.bonusExpForRank('A'));

      // 消費後は重複付与防止のためファイルが削除される
      expect(File(singleJsonPath).existsSync(), isFalse);
    });

    test('2回目の checkAndConsume は null（消費済みの回帰）', () async {
      await writeSingleJson(
        defeatEvent(taskTitle: '鬼退治', questRank: 'B', baseExp: 80),
      );
      final service = RpgTaskBonusService(filePath: singleJsonPath);

      expect(await service.checkAndConsume(), isNotNull);
      expect(await service.checkAndConsume(), isNull);
    });
  });

  group('契約B: JSONL → CrossAppAchievementAggregator', () {
    test("enemy_defeated のみを数える（3行中2行・他イベントは除外）", () async {
      await writeJsonl([
        defeatEvent(taskTitle: 'スライム掃除', questRank: 'B', baseExp: 50),
        {
          'event': 'quest_completed',
          'taskTitle': '別イベント',
          'questRank': 'B',
          'baseExp': 10,
          'timestamp': '2026-10-23T01:00:00.000Z',
        },
        defeatEvent(taskTitle: '竜退治', questRank: 'S', baseExp: 300),
      ]);

      expect(await aggregator.countEnemyDefeats(), 2);
    });

    test('空行を含む JSONL でも例外なく数える', () async {
      final line1 = jsonEncode(
        defeatEvent(taskTitle: 'Q1', questRank: 'A', baseExp: 100),
      );
      final line2 = jsonEncode(
        defeatEvent(taskTitle: 'Q2', questRank: 'B', baseExp: 40),
      );
      // 先頭・中間・末尾に空行を挟む（追記時の末尾改行を模す）
      await File(jsonlPath).writeAsString('\n$line1\n\n   \n$line2\n\n');

      expect(await aggregator.countEnemyDefeats(), 2);
    });

    test('JSONL 不在時は 0（既存挙動の回帰）', () async {
      expect(File(jsonlPath).existsSync(), isFalse);
      expect(await aggregator.countEnemyDefeats(), 0);
    });
  });

  group('契約A+B: デュアルライト共存', () {
    test('A を消費しても B の行数は減らない（両者が独立に読める）', () async {
      await writeSingleJson(
        defeatEvent(taskTitle: '同時刻の討伐', questRank: 'S', baseExp: 500),
      );
      await writeJsonl([
        defeatEvent(taskTitle: '過去の討伐1', questRank: 'B', baseExp: 50),
        defeatEvent(taskTitle: '過去の討伐2', questRank: 'A', baseExp: 120),
        defeatEvent(taskTitle: '同時刻の討伐', questRank: 'S', baseExp: 500),
      ]);

      // B は3件見えている
      expect(await aggregator.countEnemyDefeats(), 3);

      final service = RpgTaskBonusService(filePath: singleJsonPath);
      final result = await service.checkAndConsume();

      expect(result, isNotNull);
      expect(result!.taskTitle, '同時刻の討伐');
      expect(result.questRank, 'S');

      // A は消費済み、B は追記専用ログとして無傷
      expect(File(singleJsonPath).existsSync(), isFalse);
      expect(File(jsonlPath).existsSync(), isTrue);
      expect(await aggregator.countEnemyDefeats(), 3);

      // 片方だけ存在しない状態でも互いに影響しない
      await File(jsonlPath).delete();
      expect(await aggregator.countEnemyDefeats(), 0);
      expect(await service.checkAndConsume(), isNull);
    });
  });

  group('契約A: questRank S/A/B の期待ボーナスEXP', () {
    // 期待値の根拠: RpgTaskBonusService._bonusExpForRank の switch 文
    //   'S' → 50 / 'A' → 30 / 'B' → 15 / それ以外 → 0
    // 1日3回上限（maxDailyBonuses = 3）のため各ランクを個別の試練で検証する。
    const expectations = <String, int>{
      'S': 50,
      'A': 30,
      'B': 15,
    };

    for (final entry in expectations.entries) {
      final rank = entry.key;
      final expectedBonus = entry.value;

      test('questRank $rank → bonusExp $expectedBonus', () async {
        await writeSingleJson(
          defeatEvent(taskTitle: 'ランク$rank クエスト', questRank: rank, baseExp: 99),
        );

        final service = RpgTaskBonusService(filePath: singleJsonPath);
        final result = await service.checkAndConsume();

        expect(result, isNotNull);
        expect(result!.questRank, rank);
        expect(result.bonusExp, expectedBonus);
        expect(File(singleJsonPath).existsSync(), isFalse);
      });
    }
  });
}
