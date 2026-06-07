import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/receipt_scanner/data/receipt_ocr_service.dart';

void main() {
  group('ReceiptOcrResult', () {
    test('should set all fields when fully constructed', () {
      final result = ReceiptOcrResult(
        rawText: 'テストストア\n合計 ¥1,500',
        storeName: 'テストストア',
        amount: 1500,
        imagePath: '/tmp/receipt.jpg',
      );

      expect(result.rawText, 'テストストア\n合計 ¥1,500');
      expect(result.storeName, 'テストストア');
      expect(result.amount, 1500);
      expect(result.imagePath, '/tmp/receipt.jpg');
    });

    test('should allow storeName to be null', () {
      final result = ReceiptOcrResult(
        rawText: 'ただのテキスト',
        imagePath: '/tmp/receipt.jpg',
      );

      expect(result.rawText, 'ただのテキスト');
      expect(result.storeName, isNull);
      expect(result.imagePath, '/tmp/receipt.jpg');
    });

    test('should allow amount to be null', () {
      final result = ReceiptOcrResult(
        rawText: '店名のみ\nありがとうございました',
        storeName: '店名のみ',
        imagePath: '/tmp/receipt.jpg',
      );

      expect(result.rawText, '店名のみ\nありがとうございました');
      expect(result.storeName, '店名のみ');
      expect(result.amount, isNull);
      expect(result.imagePath, '/tmp/receipt.jpg');
    });

    test('should allow both storeName and amount to be null', () {
      final result = ReceiptOcrResult(
        rawText: '',
        imagePath: '/tmp/receipt.jpg',
      );

      expect(result.rawText, '');
      expect(result.storeName, isNull);
      expect(result.amount, isNull);
      expect(result.imagePath, '/tmp/receipt.jpg');
    });
  });

  group('MockReceiptOcrService', () {
    test('should return empty rawText and null fields when mockText is null', () async {
      final service = MockReceiptOcrService();
      final result = await service.processImage('/tmp/receipt.jpg');

      expect(result.rawText, '');
      expect(result.storeName, isNull);
      expect(result.amount, isNull);
      expect(result.imagePath, '/tmp/receipt.jpg');
    });

    test('should return empty rawText and null fields when mockText is empty string', () async {
      final service = MockReceiptOcrService(mockText: '');
      final result = await service.processImage('/tmp/receipt.jpg');

      expect(result.rawText, '');
      expect(result.storeName, isNull);
      expect(result.amount, isNull);
      expect(result.imagePath, '/tmp/receipt.jpg');
    });

    test('should extract storeName and amount from mockText when both are present', () async {
      final service = MockReceiptOcrService(mockText: 'テストストア\n合計 ¥1,500');
      final result = await service.processImage('/tmp/receipt.jpg');

      expect(result.rawText, 'テストストア\n合計 ¥1,500');
      expect(result.storeName, 'テストストア');
      expect(result.amount, 1500);
      expect(result.imagePath, '/tmp/receipt.jpg');
    });

    test('should extract only storeName when mockText has no amount keywords', () async {
      final service = MockReceiptOcrService(mockText: 'お店A\nありがとうございました');
      final result = await service.processImage('/tmp/receipt.jpg');

      expect(result.rawText, 'お店A\nありがとうございました');
      expect(result.storeName, 'お店A');
      expect(result.amount, isNull);
      expect(result.imagePath, '/tmp/receipt.jpg');
    });

    test('should extract only amount when mockText has no store name (starts blank)', () async {
      final service = MockReceiptOcrService(mockText: '\n\n合計 ¥980');
      final result = await service.processImage('/tmp/receipt.jpg');

      expect(result.rawText, '\n\n合計 ¥980');
      expect(result.storeName, '合計 ¥980'); // first non-empty line is "合計 ¥980"
      expect(result.amount, 980);
      expect(result.imagePath, '/tmp/receipt.jpg');
    });

    test('should pass imagePath through as provided', () async {
      final service = MockReceiptOcrService(mockText: '店');
      final result = await service.processImage('/custom/path/photo.png');

      expect(result.imagePath, '/custom/path/photo.png');
    });
  });
}
