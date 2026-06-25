import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/tsundoku/data/tsundoku_gold_luck_buff_service.dart';

void main() {
  late Directory tempDir;
  late String filePath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('tsundoku_buff_test_');
    filePath = '${tempDir.path}/tsundoku_book_completed.json';
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> writeTestJson(Map<String, dynamic> json) async {
    final file = File(filePath);
    await file.writeAsString(jsonEncode(json));
  }

  group('TsundokuGoldLuckBuffService', () {
    test('Returns null when file does not exist', () async {
      final service = TsundokuGoldLuckBuffService(filePath: filePath);
      final result = await service.checkAndConsume();
      expect(result, isNull);
    });

    test('Returns null when event type is not book_completed', () async {
      final service = TsundokuGoldLuckBuffService(filePath: filePath);
      await writeTestJson({
        'event': 'book_added',
        'bookTitle': 'テスト本',
      });

      final result = await service.checkAndConsume();
      expect(result, isNull);
    });

    test('Returns GoldLuckBuff for book_completed event', () async {
      final service = TsundokuGoldLuckBuffService(filePath: filePath);
      await writeTestJson({
        'event': 'book_completed',
        'bookTitle': '走れメロス',
      });

      final result = await service.checkAndConsume();

      expect(result, isNotNull);
      expect(result!.bookTitle, '走れメロス');
      expect(result.multiplier, 2.0);
      expect(result.isActive, isTrue);
      expect(result.source, 'book_completed');
      // 有効期限は約60分後であること
      final expiresIn = result.expiresAt.difference(DateTime.now().toUtc());
      expect(expiresIn.inMinutes, greaterThan(55));
      expect(expiresIn.inMinutes, lessThan(65));
    });

    test('File is deleted after successful consumption', () async {
      final service = TsundokuGoldLuckBuffService(filePath: filePath);
      await writeTestJson({
        'event': 'book_completed',
        'bookTitle': 'テスト本',
      });

      expect(File(filePath).existsSync(), isTrue);
      await service.checkAndConsume();
      expect(File(filePath).existsSync(), isFalse);
    });

    test('Handles missing bookTitle gracefully', () async {
      final service = TsundokuGoldLuckBuffService(filePath: filePath);
      await writeTestJson({
        'event': 'book_completed',
      });

      final result = await service.checkAndConsume();

      expect(result, isNotNull);
      expect(result!.bookTitle, isNull);
      expect(result.multiplier, 2.0);
    });

    test('Handles empty bookTitle as null', () async {
      final service = TsundokuGoldLuckBuffService(filePath: filePath);
      await writeTestJson({
        'event': 'book_completed',
        'bookTitle': '',
      });

      final result = await service.checkAndConsume();

      expect(result, isNotNull);
      expect(result!.bookTitle, isNull);
    });

    test('Handles malformed JSON gracefully', () async {
      final file = File(filePath);
      await file.writeAsString('not valid json {{{');

      final service = TsundokuGoldLuckBuffService(filePath: filePath);
      final result = await service.checkAndConsume();

      expect(result, isNull);
    });

    test('Buff duration is 60 minutes', () async {
      final service = TsundokuGoldLuckBuffService(filePath: filePath);
      await writeTestJson({
        'event': 'book_completed',
        'bookTitle': 'テスト',
      });

      final before = DateTime.now().toUtc();
      final result = await service.checkAndConsume();

      expect(result, isNotNull);
      // 有効期限は発動時刻から約60分後
      final expectedExpiry = before.add(const Duration(minutes: 60));
      final diff = result!.expiresAt.difference(expectedExpiry).abs();
      expect(diff.inSeconds, lessThan(5)); // 処理時間の誤差を許容
    });

    test('Default multiplier is 2.0', () {
      expect(TsundokuGoldLuckBuffService.defaultMultiplier, 2.0);
    });

    test('Default duration is 60 minutes', () {
      expect(TsundokuGoldLuckBuffService.defaultDuration, const Duration(minutes: 60));
    });
  });
}
