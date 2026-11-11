import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/core/format/money_format.dart';

void main() {
  group('formatYen', () {
    test('0 は ¥0（-¥0 にしない）', () {
      expect(formatYen(0), '¥0');
    });

    test('1000 未満はカンマなし', () {
      expect(formatYen(999), '¥999');
      expect(formatYen(1), '¥1');
    });

    test('1000 でカンマが入る', () {
      expect(formatYen(1000), '¥1,000');
    });

    test('19999 は ¥19,999（万略記にしない）', () {
      expect(formatYen(19999), '¥19,999');
    });

    test('負値は記号の前にマイナスを置く', () {
      expect(formatYen(-1500), '-¥1,500');
      expect(formatYen(-1), '-¥1');
    });

    test('百万は 2 つ目のカンマが入る', () {
      expect(formatYen(-1000000), '-¥1,000,000');
      expect(formatYen(1000000), '¥1,000,000');
    });
  });

  group('formatYenSigned', () {
    test('正値には + を付す', () {
      expect(formatYenSigned(1000), '+¥1,000');
    });

    test('負値は -¥ 形式のまま', () {
      expect(formatYenSigned(-1000), '-¥1,000');
    });

    test('0 は符号なしの ¥0', () {
      expect(formatYenSigned(0), '¥0');
    });
  });

  group('formatYenBare', () {
    test('記号なしの3桁カンマ', () {
      expect(formatYenBare(1000), '1,000');
    });

    test('負値は先頭にマイナス', () {
      expect(formatYenBare(-1500), '-1,500');
    });

    test('0 は 0（-0 にしない）', () {
      expect(formatYenBare(0), '0');
    });
  });

  group('formatYenCompact', () {
    test('19999 は切り捨てで 1万（2.0万 にしない）', () {
      expect(formatYenCompact(19999), '1万');
    });

    test('10000 は 1万', () {
      expect(formatYenCompact(10000), '1万');
    });

    test('9999 は formatYen に委譲する', () {
      expect(formatYenCompact(9999), '¥9,999');
    });

    test('負値は -1万', () {
      expect(formatYenCompact(-19999), '-1万');
      expect(formatYenCompact(-10000), '-1万');
    });

    test('99999 は 9万（切り捨て）', () {
      expect(formatYenCompact(99999), '9万');
    });

    test('0 は委譲して ¥0', () {
      expect(formatYenCompact(0), '¥0');
    });
  });

  group('桁境界のカンマ位置', () {
    test('999 / 1000 / 999999 / 1000000', () {
      expect(formatYen(999), '¥999');
      expect(formatYen(1000), '¥1,000');
      expect(formatYen(999999), '¥999,999');
      expect(formatYen(1000000), '¥1,000,000');
    });

    test('負値の桁境界も同じ位置', () {
      expect(formatYen(-999), '-¥999');
      expect(formatYen(-1000), '-¥1,000');
      expect(formatYen(-999999), '-¥999,999');
      expect(formatYen(-1000000), '-¥1,000,000');
    });
  });

  group('例外を投げない契約', () {
    test('int の極値でも文字列を返す', () {
      expect(formatYen(0x7FFFFFFFFFFFFFFF), startsWith('¥'));
      expect(formatYen(-0x8000000000000000), startsWith('-¥'));
      expect(formatYenCompact(0x7FFFFFFFFFFFFFFF), endsWith('万'));
      expect(formatYenCompact(-0x8000000000000000), startsWith('-¥'));
    });
  });
}
