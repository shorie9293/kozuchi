import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/features/rpg_task_bonus/data/rpg_task_bonus_service.dart';
import 'package:kozuchi/features/rpg_task_bonus/data/rpg_task_bonus_log_repository.dart';

void main() {
  late Directory tempDir;
  late String filePath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('rpg_bonus_test_');
    filePath = '${tempDir.path}/rpg_enemy_defeat_events.json';
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// テスト用のJSONファイルを書き込むヘルパー
  Future<void> writeTestJson(Map<String, dynamic> json) async {
    final file = File(filePath);
    await file.writeAsString(jsonEncode(json));
  }

  group('RpgTaskBonusService', () {
    test('Returns null when file does not exist', () async {
      final service = RpgTaskBonusService(filePath: filePath);
      final result = await service.checkAndConsume();
      expect(result, isNull);
    });

    test('Returns null when event type is not enemy_defeated', () async {
      final service = RpgTaskBonusService(filePath: filePath);
      await writeTestJson({
        'event': 'book_added',
        'taskTitle': 'Test Quest',
        'questRank': 'A',
        'baseExp': 100,
      });

      final result = await service.checkAndConsume();
      expect(result, isNull);
    });

    test('Returns RpgTaskBonusResult for S-rank quest', () async {
      final service = RpgTaskBonusService(filePath: filePath);
      await writeTestJson({
        'event': 'enemy_defeated',
        'taskTitle': '魔王討伐',
        'questRank': 'S',
        'baseExp': 200,
      });

      final result = await service.checkAndConsume();

      expect(result, isNotNull);
      expect(result!.taskTitle, '魔王討伐');
      expect(result.questRank, 'S');
      expect(result.bonusExp, 50);
      expect(result.baseExp, 200);
    });

    test('Returns RpgTaskBonusResult for A-rank quest', () async {
      final service = RpgTaskBonusService(filePath: filePath);
      await writeTestJson({
        'event': 'enemy_defeated',
        'taskTitle': '鬼退治',
        'questRank': 'A',
        'baseExp': 150,
      });

      final result = await service.checkAndConsume();

      expect(result, isNotNull);
      expect(result!.taskTitle, '鬼退治');
      expect(result.bonusExp, 30);
    });

    test('Returns RpgTaskBonusResult for B-rank quest', () async {
      final service = RpgTaskBonusService(filePath: filePath);
      await writeTestJson({
        'event': 'enemy_defeated',
        'taskTitle': 'スライム掃除',
        'questRank': 'B',
        'baseExp': 50,
      });

      final result = await service.checkAndConsume();

      expect(result, isNotNull);
      expect(result!.bonusExp, 15);
    });

    test('File is deleted after successful consumption', () async {
      final service = RpgTaskBonusService(filePath: filePath);
      await writeTestJson({
        'event': 'enemy_defeated',
        'taskTitle': 'Test',
        'questRank': 'A',
        'baseExp': 100,
      });

      expect(File(filePath).existsSync(), isTrue);
      await service.checkAndConsume();
      expect(File(filePath).existsSync(), isFalse);
    });

    test('Handles missing taskTitle gracefully', () async {
      final service = RpgTaskBonusService(filePath: filePath);
      await writeTestJson({
        'event': 'enemy_defeated',
        'questRank': 'B',
        'baseExp': 50,
      });

      final result = await service.checkAndConsume();

      expect(result, isNotNull);
      expect(result!.taskTitle, '不明なクエスト');
    });

    test('Handles invalid questRank (returns null)', () async {
      final service = RpgTaskBonusService(filePath: filePath);
      await writeTestJson({
        'event': 'enemy_defeated',
        'taskTitle': 'Test',
        'questRank': 'XYZ',
        'baseExp': 50,
      });

      final result = await service.checkAndConsume();
      // 無効ランクはnull、ファイルは消費される
      expect(result, isNull);
      expect(File(filePath).existsSync(), isFalse);
    });

    test('Daily limit: returns null after 3 bonuses', () async {
      // 日次カウントを3に設定
      final logRepo = RpgTaskBonusLogRepository();
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().toUtc();
      final todayKey =
          'rpg_bonus_daily_count_${now.year}-${_pad(now.month)}-${_pad(now.day)}';
      await prefs.setInt(todayKey, 3);

      final service = RpgTaskBonusService(filePath: filePath, logRepo: logRepo);
      await writeTestJson({
        'event': 'enemy_defeated',
        'taskTitle': '4th Quest',
        'questRank': 'A',
        'baseExp': 100,
      });

      final result = await service.checkAndConsume();
      expect(result, isNull);
      // ファイルは消費されない（上限チェックが先）
      expect(File(filePath).existsSync(), isTrue);
    });

    test('getRemainingBonusesToday returns correct count', () async {
      final logRepo = RpgTaskBonusLogRepository();
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().toUtc();
      final todayKey =
          'rpg_bonus_daily_count_${now.year}-${_pad(now.month)}-${_pad(now.day)}';
      await prefs.setInt(todayKey, 1);

      final service = RpgTaskBonusService(filePath: filePath, logRepo: logRepo);
      final remaining = await service.getRemainingBonusesToday();
      expect(remaining, 2);
    });

    test('Handles malformed JSON gracefully', () async {
      final file = File(filePath);
      await file.writeAsString('not valid json {{{');

      final service = RpgTaskBonusService(filePath: filePath);
      final result = await service.checkAndConsume();

      expect(result, isNull);
    });

    test('bonusExpForRank returns correct values', () {
      expect(RpgTaskBonusService.bonusExpForRank('S'), 50);
      expect(RpgTaskBonusService.bonusExpForRank('A'), 30);
      expect(RpgTaskBonusService.bonusExpForRank('B'), 15);
      expect(RpgTaskBonusService.bonusExpForRank('s'), 50); // case insensitive
      expect(RpgTaskBonusService.bonusExpForRank('X'), 0);
    });
  });
}

String _pad(int n) => n.toString().padLeft(2, '0');
