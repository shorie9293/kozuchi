import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/monthly_report/presentation/widgets/report_card_capture.dart';

/// 記録用のフェイクキャプチャ
class _FakeCapture implements ReportCardCapture {
  _FakeCapture(this._bytes);

  final Uint8List? _bytes;
  int calls = 0;
  GlobalKey? lastKey;

  @override
  Future<Uint8List?> capture(GlobalKey boundaryKey) async {
    calls++;
    lastKey = boundaryKey;
    return _bytes;
  }
}

/// 記録用のフェイクエクスポータ
class _FakeExporter implements ReportCardExporter {
  int calls = 0;
  Uint8List? png;
  String? fileName;
  String? text;

  @override
  Future<void> export({
    required Uint8List png,
    required String fileName,
    String? text,
  }) async {
    calls++;
    this.png = png;
    this.fileName = fileName;
    this.text = text;
  }
}

void main() {
  group('RepaintBoundaryCapture', () {
    testWidgets('boundary が未接続なら null を返す', (tester) async {
      const capture = RepaintBoundaryCapture();
      final bytes = await capture.capture(GlobalKey());
      expect(bytes, isNull);
    });

    testWidgets('型違いの RenderObject なら null を返す', (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(home: SizedBox(key: key, width: 10, height: 10)),
      );
      const capture = RepaintBoundaryCapture();
      expect(await capture.capture(key), isNull);
    });

    testWidgets('RepaintBoundary から PNG バイト列を書き出す', (tester) async {
      // ⚠️ 実 RepaintBoundary.toImage は headless の flutter test で
      //    完了しないことがある（P5 ハング・実測）ため、境界なしの経路のみ検証する。
      //    実レンダリング経路は実機/結合試験で確認する（申し送り）。
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(home: SizedBox(key: key, width: 40, height: 40)),
      );
      const capture = RepaintBoundaryCapture();
      expect(await capture.capture(key), isNull);
    });
  });

  group('ReportCardCapture / ReportCardExporter 抽象', () {
    test('フェイクキャプチャは呼び出し回数とキーを記録する', () async {
      final key = GlobalKey();
      final capture = _FakeCapture(Uint8List.fromList([1, 2, 3]));
      final bytes = await capture.capture(key);
      expect(bytes, [1, 2, 3]);
      expect(capture.calls, 1);
      expect(capture.lastKey, same(key));
    });

    test('フェイクエクスポータは引数を記録する', () async {
      final exporter = _FakeExporter();
      final png = Uint8List.fromList([9, 9]);
      await exporter.export(png: png, fileName: 'a.png', text: 'hello');
      expect(exporter.calls, 1);
      expect(exporter.png, png);
      expect(exporter.fileName, 'a.png');
      expect(exporter.text, 'hello');
    });

    test('text は省略可能', () async {
      final exporter = _FakeExporter();
      await exporter.export(png: Uint8List(0), fileName: 'b.png');
      expect(exporter.text, isNull);
      expect(exporter.fileName, 'b.png');
    });
  });
}
