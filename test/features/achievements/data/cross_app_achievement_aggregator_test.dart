import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/achievements/data/cross_app_achievement_aggregator.dart';

void main() {
  late Directory tempDir;
  late CrossAppAchievementAggregator aggregator;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('cross_app_agg_test_');
    aggregator = CrossAppAchievementAggregator(basePath: tempDir.path);
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('CrossAppAchievementAggregator - countEnemyDefeats', () {
    test('Returns 0 when file does not exist', () async {
      final count = await aggregator.countEnemyDefeats();
      expect(count, 0);
    });

    test('Counts enemy_defeated events in JSONL file', () async {
      final file = File('${tempDir.path}/rpg_enemy_defeat_events.jsonl');
      await file.writeAsString('''
{"event": "enemy_defeated", "taskTitle": "Quest 1", "questRank": "A"}
{"event": "enemy_defeated", "taskTitle": "Quest 2", "questRank": "S"}
{"event": "book_added", "taskTitle": "Not a defeat"}
''');

      final count = await aggregator.countEnemyDefeats();
      expect(count, 2);
    });

    test('Handles malformed JSONL lines gracefully', () async {
      final file = File('${tempDir.path}/rpg_enemy_defeat_events.jsonl');
      await file.writeAsString('''
{"event": "enemy_defeated"}
not valid json
{"event": "enemy_defeated"}
''');

      final count = await aggregator.countEnemyDefeats();
      expect(count, 2);
    });

    test('Handles empty JSONL file', () async {
      final file = File('${tempDir.path}/rpg_enemy_defeat_events.jsonl');
      await file.writeAsString('');

      final count = await aggregator.countEnemyDefeats();
      expect(count, 0);
    });
  });

  group('CrossAppAchievementAggregator - countBooksRead', () {
    test('Returns 0 when no files exist', () async {
      final count = await aggregator.countBooksRead();
      expect(count, 0);
    });

    test('Counts single JSON book_completed event', () async {
      final file = File('${tempDir.path}/tsundoku_book_completed.json');
      await file.writeAsString(jsonEncode({
        'event': 'book_completed',
        'bookTitle': '走れメロス',
      }));

      final count = await aggregator.countBooksRead();
      expect(count, 1);
    });

    test('Counts JSONL book_completed events', () async {
      final file = File('${tempDir.path}/tsundoku_reward_events.jsonl');
      await file.writeAsString('''
{"event_type": "book_completed", "bookTitle": "Book 1"}
{"event_type": "book_completed", "bookTitle": "Book 2"}
{"event_type": "book_added", "bookTitle": "Not completed"}
''');

      final count = await aggregator.countBooksRead();
      expect(count, 2);
    });

    test('Counts both single JSON and JSONL events', () async {
      // Single JSON
      final singleFile = File('${tempDir.path}/tsundoku_book_completed.json');
      await singleFile.writeAsString(jsonEncode({
        'event': 'book_completed',
        'bookTitle': 'Book A',
      }));

      // JSONL
      final jsonlFile = File('${tempDir.path}/tsundoku_reward_events.jsonl');
      await jsonlFile.writeAsString('''
{"event_type": "book_completed", "bookTitle": "Book B"}
{"event_type": "book_completed", "bookTitle": "Book C"}
''');

      final count = await aggregator.countBooksRead();
      expect(count, 3);
    });
  });

  group('CrossAppAchievementAggregator - countGoldEarned', () {
    test('Returns the passed value as-is', () {
      expect(aggregator.countGoldEarned(500), 500);
      expect(aggregator.countGoldEarned(0), 0);
      expect(aggregator.countGoldEarned(9999), 9999);
    });
  });

  group('CrossAppAchievementAggregator - ThreeWorldsConquest', () {
    test('allMet is true when all conditions are met', () async {
      // Setup: 10 enemies defeated
      final enemyFile = File('${tempDir.path}/rpg_enemy_defeat_events.jsonl');
      final enemyLines = List.generate(10, (i) => '{"event": "enemy_defeated", "taskTitle": "Quest $i"}');
      await enemyFile.writeAsString(enemyLines.join('\n'));

      // Setup: 5 books read
      final bookFile = File('${tempDir.path}/tsundoku_reward_events.jsonl');
      final bookLines = List.generate(5, (i) => '{"event_type": "book_completed", "bookTitle": "Book $i"}');
      await bookFile.writeAsString(bookLines.join('\n'));

      final status = await aggregator.checkThreeWorldsConquest(goldEarned: 1000);

      expect(status.allMet, isTrue);
      expect(status.conditions.enemiesDefeated, 10);
      expect(status.conditions.booksRead, 5);
      expect(status.conditions.goldEarned, 1000);
      expect(status.unmetReasons, isEmpty);
    });

    test('allMet is false when enemies defeated is insufficient', () async {
      final enemyFile = File('${tempDir.path}/rpg_enemy_defeat_events.jsonl');
      await enemyFile.writeAsString('{"event": "enemy_defeated"}\n');

      final status = await aggregator.checkThreeWorldsConquest(goldEarned: 2000);

      expect(status.allMet, isFalse);
      expect(status.unmetReasons, contains('敵討伐: 1/10'));
    });

    test('allMet is false when books read is insufficient', () async {
      // 10 enemies
      final enemyFile = File('${tempDir.path}/rpg_enemy_defeat_events.jsonl');
      final enemyLines = List.generate(10, (i) => '{"event": "enemy_defeated", "taskTitle": "Q$i"}');
      await enemyFile.writeAsString(enemyLines.join('\n'));

      final status = await aggregator.checkThreeWorldsConquest(goldEarned: 2000);

      expect(status.allMet, isFalse);
      expect(status.unmetReasons, contains('読了: 0/5'));
    });

    test('allMet is false when gold earned is insufficient', () async {
      // 10 enemies
      final enemyFile = File('${tempDir.path}/rpg_enemy_defeat_events.jsonl');
      final enemyLines = List.generate(10, (i) => '{"event": "enemy_defeated", "taskTitle": "Q$i"}');
      await enemyFile.writeAsString(enemyLines.join('\n'));

      // 5 books
      final bookFile = File('${tempDir.path}/tsundoku_reward_events.jsonl');
      final bookLines = List.generate(5, (i) => '{"event_type": "book_completed", "bookTitle": "B$i"}');
      await bookFile.writeAsString(bookLines.join('\n'));

      final status = await aggregator.checkThreeWorldsConquest(goldEarned: 500);

      expect(status.allMet, isFalse);
      expect(status.unmetReasons, contains('金獲得: 500/1000'));
    });

    test('allMet is false when multiple conditions are unmet', () async {
      final status = await aggregator.checkThreeWorldsConquest(goldEarned: 100);

      expect(status.allMet, isFalse);
      expect(status.unmetReasons.length, 3);
      expect(status.unmetReasons, contains('敵討伐: 0/10'));
      expect(status.unmetReasons, contains('読了: 0/5'));
      expect(status.unmetReasons, contains('金獲得: 100/1000'));
    });
  });
}
