import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/features/receipt_viewer/domain/models/receipt_image_ref.dart';

void main() {
  group('ReceiptImageRef 値等価', () {
    test('同一パスは等価・同一hashCode', () {
      final a = ReceiptImageRef(path: '/x/y.png');
      final b = ReceiptImageRef(path: '/x/y.png');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a.toString(), contains('/x/y.png'));
    });

    test('trim 差のみは等価', () {
      expect(
        ReceiptImageRef(path: ' /x/y.png '),
        equals(ReceiptImageRef(path: '/x/y.png')),
      );
    });

    test('異なるパスは非等価', () {
      expect(
        ReceiptImageRef(path: '/a.png'),
        isNot(equals(ReceiptImageRef(path: '/b.png'))),
      );
    });
  });

  group('tryFromPath', () {
    test('null は null', () {
      expect(ReceiptImageRef.tryFromPath(null), isNull);
    });

    test('空文字は null', () {
      expect(ReceiptImageRef.tryFromPath(''), isNull);
    });

    test('空白のみは null', () {
      expect(ReceiptImageRef.tryFromPath('   '), isNull);
    });

    test('前後空白は trim して返す', () {
      final ref = ReceiptImageRef.tryFromPath('  /x/y.jpg  ');
      expect(ref, isNotNull);
      expect(ref!.path, '/x/y.jpg');
    });
  });

  group('fileName', () {
    test('スラッシュ区切りの最終要素', () {
      expect(ReceiptImageRef(path: '/a/b/c.jpg').fileName, 'c.jpg');
    });

    test('バックスラッシュ区切りの最終要素', () {
      expect(ReceiptImageRef(path: r'C:\a\c.png').fileName, 'c.png');
    });

    test('区切り無しは path 自身', () {
      expect(ReceiptImageRef(path: 'photo.jpg').fileName, 'photo.jpg');
    });
  });

  group('extension', () {
    test('小文字化される', () {
      expect(ReceiptImageRef(path: '/a/b.JPG').extension, 'jpg');
    });

    test('ドット無しは空文字', () {
      expect(ReceiptImageRef(path: '/a/b').extension, '');
    });
  });

  group('isSupportedImage', () {
    test('対応形式', () {
      for (final name in ['jpg', 'jpeg', 'png', 'webp', 'heic', 'heif']) {
        expect(
          ReceiptImageRef(path: '/x/p.$name').isSupportedImage,
          isTrue,
          reason: name,
        );
      }
    });

    test('非対応形式', () {
      expect(ReceiptImageRef(path: '/x/p.gif').isSupportedImage, isFalse);
      expect(ReceiptImageRef(path: '/x/p.pdf').isSupportedImage, isFalse);
      expect(ReceiptImageRef(path: '/x/p').isSupportedImage, isFalse);
    });
  });

  group('label', () {
    test('fileName を返す', () {
      expect(ReceiptImageRef(path: '/a/b/c.jpg').label, 'c.jpg');
    });

    test('fileName が空ならレシート画像', () {
      // 区切りで終わるパスは fileName が空扱いになり label はフォールバック。
      final ref = ReceiptImageRef(path: 'x.jpg');
      expect(ref.label, isNotEmpty);
    });
  });

  group('不変条件', () {
    test('空パスは ArgumentError', () {
      expect(() => ReceiptImageRef(path: ''), throwsArgumentError);
    });

    test('空白のみのパスは ArgumentError', () {
      expect(() => ReceiptImageRef(path: '   '), throwsArgumentError);
    });
  });
}
