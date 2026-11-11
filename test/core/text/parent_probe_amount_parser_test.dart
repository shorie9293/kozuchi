import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/core/text/amount_parser.dart';
import 'package:kozuchi/features/transaction_edit/domain/services/transaction_edit_service.dart';

/// 親探針（イシコリドメ）: 眷属の試練とは独立に、正準パーサの不変条件を撃つ。
///
/// 目的:
/// 1. 全角数字・カンマ・空白・マイナスを吸収しても例外を投げない
/// 2. 巨大数・混在文字列でも throw しない（int.tryParse の範囲外）
/// 3. 既存の TransactionEditService.parseAmount が同じ真実源を通る（二重実装の不在）
void main() {
  group('親探針: AmountParser の不変条件', () {
    test('全角数字と区切りを吸収して同一値になる', () {
      expect(AmountParser.tryParse('１２３'), 123);
      expect(AmountParser.tryParse('１２３４５'), 12345);
      expect(AmountParser.tryParse('１，２３４'), 1234);
      expect(AmountParser.tryParse('1,234'), 1234);
      expect(AmountParser.tryParse(' 45 '), 45);
      expect(AmountParser.tryParse('　４５　'), 45);
      // 全角・半角の混在も畳める
      expect(AmountParser.tryParse('1２3４'), 1234);
    });

    test('全角マイナスは負値として解釈され、既定では拒否される', () {
      expect(AmountParser.tryParse('－５００'), isNull);
      expect(AmountParser.tryParse('－５００', allowNegative: true), -500);
      expect(AmountParser.tryParse('\u2212500', allowNegative: true), -500);
    });

    test('0 は既定で拒否・allowZero で許可', () {
      expect(AmountParser.tryParse('0'), isNull);
      expect(AmountParser.tryParse('０'), isNull);
      expect(AmountParser.tryParse('０', allowZero: true), 0);
      expect(AmountParser.parseAmount('0').errorMessage,
          AmountParser.zeroNotAllowedMessage);
    });

    test('異常入力でも例外を投げず null と理由を返す', () {
      for (final raw in <String>[
        '',
        '   ',
        'abc',
        '１２３abc',
        '¥1,000',
        '1.5',
        '--5',
      ]) {
        expect(() => AmountParser.tryParse(raw), returnsNormally,
            reason: 'tryParse("$raw") は例外を投げてはならない');
        expect(AmountParser.tryParse(raw), isNull, reason: 'raw="$raw"');
        final result = AmountParser.parseAmount(raw);
        expect(result.value, isNull, reason: 'raw="$raw"');
        expect(result.errorMessage, isNotNull, reason: 'raw="$raw"');
        expect(result.isValid, isFalse);
      }
    });

    test('int の範囲を超える数字列でも throw せず理由を返す', () {
      const huge = '９９９９９９９９９９９９９９９９９９９９９９';
      expect(() => AmountParser.parseAmount(huge), returnsNormally);
      final result = AmountParser.parseAmount(huge);
      expect(result.value, isNull);
      expect(result.errorMessage, AmountParser.notNumberMessage);
    });

    test('空入力の理由は「入力してください」であり 0 ではない', () {
      expect(AmountParser.parseAmount('').errorMessage,
          AmountParser.emptyMessage);
      expect(AmountParser.parseAmount('　').errorMessage,
          AmountParser.emptyMessage);
    });
  });

  group('親探針: 既存 parseAmount が同一の真実源を通る', () {
    test('全角・カンマ・空白・0・負値の判定が AmountParser と一致する', () {
      const inputs = <String>[
        '１２３',
        '1,234',
        ' 45 ',
        '０',
        '0',
        '-100',
        'abc',
        '',
      ];
      for (final raw in inputs) {
        expect(
          TransactionEditService.parseAmount(raw),
          AmountParser.tryParse(raw),
          reason: 'raw="$raw" で二重実装が生じている',
        );
      }
    });

    test('委譲後も全角の 0 は null（黙って 0 にしない）', () {
      expect(TransactionEditService.parseAmount('０'), isNull);
    });
  });
}
