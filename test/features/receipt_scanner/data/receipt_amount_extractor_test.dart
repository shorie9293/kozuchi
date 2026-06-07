import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/receipt_scanner/data/receipt_amount_extractor.dart';

void main() {
  group('ReceiptAmountExtractor', () {
    late ReceiptAmountExtractor extractor;

    setUp(() {
      extractor = ReceiptAmountExtractor();
    });

    group('extractAmount', () {
      test('should extract amount preceded by 合計', () {
        final text = '''
株式会社〇〇商店
2024年1月15日
合計 ¥1,280
現金 ¥1,280
お釣り ¥0
''';
        final result = extractor.extract(text);
        expect(result.amount, 1280);
      });

      test('should extract amount preceded by お支払い', () {
        final text = '''
レシート
お支払い ¥5,400
ありがとうございました
''';
        final result = extractor.extract(text);
        expect(result.amount, 5400);
      });

      test('should extract amount preceded by 小計', () {
        final text = '小計 ¥980';
        final result = extractor.extract(text);
        expect(result.amount, 980);
      });

      test('should extract amount preceded by 合計金額', () {
        final text = '合計金額 3,500円';
        final result = extractor.extract(text);
        expect(result.amount, 3500);
      });

      test('should extract amount with 円 suffix', () {
        final text = '合計 820円（内税）';
        final result = extractor.extract(text);
        expect(result.amount, 820);
      });

      test('should extract amount without comma', () {
        final text = '合計 ¥120';
        final result = extractor.extract(text);
        expect(result.amount, 120);
      });

      test('should extract large amount', () {
        final text = 'お支払い ¥128,500';
        final result = extractor.extract(text);
        expect(result.amount, 128500);
      });

      test('should return null when no amount found', () {
        final text = 'ありがとうございました';
        final result = extractor.extract(text);
        expect(result.amount, isNull);
      });

      test('should prefer 合計 over 小計 when both present', () {
        final text = '''
小計 ¥2,500
消費税 ¥250
合計 ¥2,750
''';
        final result = extractor.extract(text);
        expect(result.amount, 2750);
      });
    });

    group('extractStoreName', () {
      test('should extract store name from first line', () {
        final text = '''
株式会社〇〇商店
2024年1月15日
合計 ¥1,280
''';
        final result = extractor.extract(text);
        expect(result.storeName, '株式会社〇〇商店');
      });

      test('should extract store name with 店 suffix', () {
        final text = '''
スーパーやまだ 新宿店
TEL: 03-1234-5678
お支払い ¥3,200
''';
        final result = extractor.extract(text);
        expect(result.storeName, 'スーパーやまだ 新宿店');
      });

      test('should return null for empty text', () {
        final result = extractor.extract('');
        expect(result.storeName, isNull);
        expect(result.amount, isNull);
      });

      test('should skip blank first lines', () {
        final text = '''


セブン-イレブン 目黒店
合計 ¥550
''';
        final result = extractor.extract(text);
        expect(result.storeName, 'セブン-イレブン 目黒店');
      });
    });

    group('extract with full receipt', () {
      test('should extract both amount and store name', () {
        final text = '''
ファミリーマート 渋谷店
2024/01/15 14:30
おにぎり ¥150
お茶 ¥120
合計 ¥270
現金 ¥270
''';
        final result = extractor.extract(text);
        expect(result.storeName, 'ファミリーマート 渋谷店');
        expect(result.amount, 270);
      });
    });
  });
}
