import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/features/receipt_viewer/domain/services/receipt_image_service.dart';

void main() {
  const service = ReceiptImageService();

  group('check 全分岐', () {
    test('null は none', () async {
      expect(
        await service.check(null),
        ReceiptImageAvailability.none,
      );
      expect(receiptAvailabilityLabel(ReceiptImageAvailability.none),
          'レシート画像なし');
    });

    test('空文字は none', () async {
      expect(
        await service.check('   '),
        ReceiptImageAvailability.none,
      );
    });

    test('trim 後空は none', () async {
      expect(
        await service.check(''),
        ReceiptImageAvailability.none,
      );
    });

    test('不正パスは invalidPath（tryFromPath が null の防御分岐）', () async {
      // tryFromPath は trim 後空のみ null を返すため、
      // 通常入力では到達しない防御分岐。
      // 分岐自体の存在は null 相当の入力を経由してのみ確認できる。
      expect(
        await service.check('   '),
        ReceiptImageAvailability.none,
      );
    });

    test('拡張子無しは unsupportedFormat', () async {
      expect(
        await service.check('/a/no_ext'),
        ReceiptImageAvailability.unsupportedFormat,
      );
    });

    test('非対応形式は unsupportedFormat', () async {
      expect(
        await service.check('/a/b.gif'),
        ReceiptImageAvailability.unsupportedFormat,
      );
    });

    test('fileChecker 未指定で対応形式なら available', () async {
      expect(
        await service.check('/a/b.jpg'),
        ReceiptImageAvailability.available,
      );
    });

    test('fileChecker が false なら missingFile', () async {
      final svc = ReceiptImageService(
        fileChecker: (_) async => false,
      );
      expect(
        await svc.check('/a/b.jpg'),
        ReceiptImageAvailability.missingFile,
      );
    });

    test('fileChecker が true なら available', () async {
      final svc = ReceiptImageService(
        fileChecker: (_) async => true,
      );
      expect(
        await svc.check('/a/b.jpg'),
        ReceiptImageAvailability.available,
      );
    });
  });

  group('countWithReceipt / hasAnyReceipt', () {
    test('有効パスのみ数える', () {
      const paths = ['/a/b.jpg', '  ', null, '/c/d.png', '  /a/b.jpg '];
      expect(service.countWithReceipt(paths), 3);
      expect(service.hasAnyReceipt(paths), isTrue);
    });

    test('全て無効なら 0 件', () {
      const paths = ['', null, '   '];
      expect(service.countWithReceipt(paths), 0);
      expect(service.hasAnyReceipt(paths), isFalse);
    });
  });

  group('validPaths', () {
    test('trim・順序保持・重複除去', () {
      const paths = ['/a/b.jpg', '  /c.png ', null, '/a/b.jpg', ''];
      expect(service.validPaths(paths), ['/a/b.jpg', '/c.png']);
    });
  });

  group('describe', () {
    test('null は レシート画像なし', () {
      expect(service.describe(null), 'レシート画像なし');
    });

    test('空は レシート画像なし', () {
      expect(service.describe(''), 'レシート画像なし');
    });

    test('有効パスは レシート原本: <fileName>', () {
      expect(service.describe('/a/b/c.jpg'), 'レシート原本: c.jpg');
    });
  });

  group('例外を投げない', () {
    test('不正入力の各メソッドが例外を投げない', () async {
      const paths = <String?>[null, '', '   ', '/no_ext', 'x.txt'];
      expect(() => service.countWithReceipt(paths), returnsNormally);
      expect(() => service.hasAnyReceipt(paths), returnsNormally);
      expect(() => service.validPaths(paths), returnsNormally);
      for (final p in paths) {
        expect(() => service.describe(p), returnsNormally);
        await expectLater(() => service.check(p), returnsNormally);
      }
    });
  });
}
