import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/core/text/amount_parser.dart';

void main() {
  group('AmountParser.normalize', () {
    test('全角数字を半角へ変換する', () {
      expect(AmountParser.normalize('１２３'), '123');
    });

    test('全角カンマ・半角カンマを取り除く', () {
      expect(AmountParser.normalize('１，２３４'), '1234');
      expect(AmountParser.normalize('1,234'), '1234');
    });

    test('全角空白を半角へ変換し前後の空白を除去する', () {
      expect(AmountParser.normalize('　４５　'), '45');
      expect(AmountParser.normalize(' 45 '), '45');
    });

    test('全角マイナス・数学マイナスを半角ハイフンへ変換する', () {
      expect(AmountParser.normalize('－８５０００'), '-85000');
      expect(AmountParser.normalize('\u22128５000'), '-85000');
    });

    test('空文字は空文字のまま', () {
      expect(AmountParser.normalize(''), '');
      expect(AmountParser.normalize('   '), '');
    });
  });

  group('AmountParser.tryParse', () {
    test('全角数字を通貨として解釈する', () {
      expect(AmountParser.tryParse('１２３'), 123);
    });

    test('全角カンマ入りの全角数字を解釈する', () {
      expect(AmountParser.tryParse('１，２３４'), 1234);
    });

    test('前後の空白を許容する', () {
      expect(AmountParser.tryParse(' 45 '), 45);
    });

    test('全角5桁を解釈する', () {
      expect(AmountParser.tryParse('１２３４５'), 12345);
    });

    test('空文字・非数は null', () {
      expect(AmountParser.tryParse(''), isNull);
      expect(AmountParser.tryParse('   '), isNull);
      expect(AmountParser.tryParse('abc'), isNull);
      expect(AmountParser.tryParse('１００円'), isNull);
    });

    test('既定では 0 は null', () {
      expect(AmountParser.tryParse('0'), isNull);
      expect(AmountParser.tryParse('０'), isNull);
    });

    test('allowZero なら 0 を許容する', () {
      expect(AmountParser.tryParse('0', allowZero: true), 0);
    });

    test('既定では負値は null', () {
      expect(AmountParser.tryParse('-100'), isNull);
    });

    test('allowNegative なら負値を許容する（定期取引の支出）', () {
      expect(AmountParser.tryParse('－８５０００', allowNegative: true), -85000);
      expect(AmountParser.tryParse('-85000', allowNegative: true), -85000);
    });

    test('桁あふれでも例外を投げず null', () {
      expect(AmountParser.tryParse('9' * 40), isNull);
    });

    test('例外を投げない（記号のみ・全角記号）', () {
      expect(() => AmountParser.tryParse('¥'), returnsNormally);
      expect(AmountParser.tryParse('¥'), isNull);
      expect(AmountParser.tryParse('--5'), isNull);
    });
  });

  group('AmountParser.parseAmount', () {
    test('正常値は value を返し errorMessage は null', () {
      final r = AmountParser.parseAmount('１２３');
      expect(r.value, 123);
      expect(r.errorMessage, isNull);
      expect(r.isValid, isTrue);
    });

    test('空文字は日本語の理由を返す', () {
      final r = AmountParser.parseAmount('  ');
      expect(r.value, isNull);
      expect(r.errorMessage, AmountParser.emptyMessage);
      expect(r.isValid, isFalse);
    });

    test('非数は日本語の理由を返す', () {
      final r = AmountParser.parseAmount('abc');
      expect(r.value, isNull);
      expect(r.errorMessage, AmountParser.notNumberMessage);
    });

    test('0 は日本語の理由を返す', () {
      final r = AmountParser.parseAmount('0');
      expect(r.value, isNull);
      expect(r.errorMessage, isNotNull);
    });

    test('allowZero なら 0 を value として返す', () {
      final r = AmountParser.parseAmount('０', allowZero: true);
      expect(r.value, 0);
      expect(r.errorMessage, isNull);
    });

    test('負値は日本語の理由を返す', () {
      final r = AmountParser.parseAmount('-100');
      expect(r.value, isNull);
      expect(r.errorMessage, isNotNull);
    });

    test('allowNegative なら負値を value として返す', () {
      final r = AmountParser.parseAmount('－１００', allowNegative: true);
      expect(r.value, -100);
      expect(r.errorMessage, isNull);
    });
  });
}
