import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/features/receipt_viewer/data/receipt_image_loader.dart';

/// 試練用のダミーバイト列。
final Uint8List dummyBytes = Uint8List.fromList(<int>[1, 2, 3, 4]);

void main() {
  group('InMemoryReceiptImageLoader', () {
    test('登録済みパスはバイト列を返す', () async {
      final loader = InMemoryReceiptImageLoader({
        '/x/a.jpg': dummyBytes,
      });
      expect(await loader.load('/x/a.jpg'), same(dummyBytes));
    });

    test('未登録パスは null', () async {
      const loader = InMemoryReceiptImageLoader({});
      expect(await loader.load('/x/missing.jpg'), isNull);
    });
  });

  group('FileReceiptImageLoader', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('receipt_loader_test');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('実ファイルを読み出せる', () async {
      final file = File('${tempDir.path}/receipt.jpg');
      await file.writeAsBytes(dummyBytes);
      const loader = FileReceiptImageLoader();
      expect(await loader.load(file.path), equals(dummyBytes));
    });

    test('不在パスは null', () async {
      const loader = FileReceiptImageLoader();
      expect(
        await loader.load('${tempDir.path}/missing.jpg'),
        isNull,
      );
    });
  });

  group('FakeReceiptImageLoader', () {
    test('呼び出しを記録し結果を返す', () async {
      final loader = FakeReceiptImageLoader(result: dummyBytes);
      expect(await loader.load('/fake.png'), same(dummyBytes));
      expect(loader.calls, ['/fake.png']);
    });
  });
}
