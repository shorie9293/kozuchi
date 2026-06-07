import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/benzaiten/data/benzaiten_book_bonus_service.dart';
import 'package:kozuchi/domain/models/guardian_deity.dart';

void main() {
  late Directory tempDir;
  late String filePath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('benzaiten_test_');
    filePath = '${tempDir.path}/tsundoku_book_events.json';
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// テスト用のJSONファイルを書き込むヘルパー
  Future<void> writeTestJson(Map<String, dynamic> json) async {
    final file = File(filePath);
    await file.writeAsString(jsonEncode(json));
  }

  group('BenzaitenBookBonusService', () {
    test('Returns null when guardian is daikokuten', () async {
      final service = BenzaitenBookBonusService(filePath: filePath);
      await writeTestJson({
        'event': 'book_added',
        'bookTitle': 'Test Book',
        'bookAuthor': 'Author',
        'timestamp': '2026-05-21T12:00:00.000Z',
      });

      final result = await service.checkAndConsume(GuardianDeity.daikokuten);

      expect(result, isNull);
    });

    test('Returns null when guardian is bishamonten', () async {
      final service = BenzaitenBookBonusService(filePath: filePath);
      await writeTestJson({
        'event': 'book_added',
        'bookTitle': 'Test Book',
        'bookAuthor': 'Author',
        'timestamp': '2026-05-21T12:00:00.000Z',
      });

      final result = await service.checkAndConsume(GuardianDeity.bishamonten);

      expect(result, isNull);
    });

    test('Returns null when guardian is kisshoten', () async {
      final service = BenzaitenBookBonusService(filePath: filePath);
      await writeTestJson({
        'event': 'book_added',
        'bookTitle': 'Test Book',
        'bookAuthor': 'Author',
        'timestamp': '2026-05-21T12:00:00.000Z',
      });

      final result = await service.checkAndConsume(GuardianDeity.kisshoten);

      expect(result, isNull);
    });

    test('Returns null when file does not exist', () async {
      final service = BenzaitenBookBonusService(filePath: filePath);

      final result = await service.checkAndConsume(GuardianDeity.benzaiten);

      expect(result, isNull);
    });

    test('Returns null when event type is not book_added', () async {
      final service = BenzaitenBookBonusService(filePath: filePath);
      await writeTestJson({
        'event': 'book_removed',
        'bookTitle': 'Test Book',
        'bookAuthor': 'Author',
        'timestamp': '2026-05-21T12:00:00.000Z',
      });

      final result = await service.checkAndConsume(GuardianDeity.benzaiten);

      expect(result, isNull);
    });

    test('Returns BenzaitenBonusResult when guardian is Benzaiten and file has valid book_added event', () async {
      final service = BenzaitenBookBonusService(filePath: filePath);
      await writeTestJson({
        'event': 'book_added',
        'bookTitle': 'Some Book Title',
        'bookAuthor': 'Author Name',
        'timestamp': '2026-05-21T12:00:00.000Z',
      });

      final result = await service.checkAndConsume(GuardianDeity.benzaiten);

      expect(result, isNotNull);
      expect(result!.bookTitle, 'Some Book Title');
      expect(result.bookAuthor, 'Author Name');
      expect(result.bonusSatori, 10);
    });

    test('File is deleted after successful consumption', () async {
      final service = BenzaitenBookBonusService(filePath: filePath);
      await writeTestJson({
        'event': 'book_added',
        'bookTitle': 'Some Book Title',
        'bookAuthor': 'Author Name',
        'timestamp': '2026-05-21T12:00:00.000Z',
      });

      expect(File(filePath).existsSync(), isTrue);

      await service.checkAndConsume(GuardianDeity.benzaiten);

      expect(File(filePath).existsSync(), isFalse);
    });

    test('Handles bookAuthor being empty string (becomes null)', () async {
      final service = BenzaitenBookBonusService(filePath: filePath);
      await writeTestJson({
        'event': 'book_added',
        'bookTitle': 'Some Book Title',
        'bookAuthor': '',
        'timestamp': '2026-05-21T12:00:00.000Z',
      });

      final result = await service.checkAndConsume(GuardianDeity.benzaiten);

      expect(result, isNotNull);
      expect(result!.bookTitle, 'Some Book Title');
      expect(result.bookAuthor, isNull);
      expect(result.bonusSatori, 10);
    });

    test('Handles bookAuthor being present', () async {
      final service = BenzaitenBookBonusService(filePath: filePath);
      await writeTestJson({
        'event': 'book_added',
        'bookTitle': 'Another Book',
        'bookAuthor': 'Jane Doe',
        'timestamp': '2026-05-21T12:00:00.000Z',
      });

      final result = await service.checkAndConsume(GuardianDeity.benzaiten);

      expect(result, isNotNull);
      expect(result!.bookTitle, 'Another Book');
      expect(result.bookAuthor, 'Jane Doe');
      expect(result.bonusSatori, 10);
    });
  });

  group('BenzaitenBonusResult', () {
    test('constructor sets all fields', () {
      final result = BenzaitenBonusResult(bookTitle: 'Test', bonusSatori: 10);
      expect(result.bookTitle, 'Test');
      expect(result.bookAuthor, isNull);
      expect(result.bonusSatori, 10);
    });
  });
}
