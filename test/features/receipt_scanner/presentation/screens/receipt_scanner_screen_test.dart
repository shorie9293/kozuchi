import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kozuchi/features/receipt_scanner/data/receipt_ocr_service.dart';
import 'package:kozuchi/features/receipt_scanner/presentation/screens/receipt_scanner_screen.dart';

/// テスト用のモックImagePicker
///
/// pickImageを呼ぶとダミーのXFileを返す。
/// cancelled=trueにするとnullを返す（ユーザーキャンセル模擬）。
class MockImagePicker extends ImagePicker {
  final bool cancelled;
  final String mockPath;

  MockImagePicker({
    this.cancelled = false,
    this.mockPath = '/tmp/mock_receipt.jpg',
  });

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    if (cancelled) return null;
    return XFile(mockPath);
  }
}

void main() {
  group('ReceiptScannerScreen', () {
    testWidgets('should display camera icon and capture button', (tester) async {
      final ocrService = MockReceiptOcrService();

      await tester.pumpWidget(
        MaterialApp(
          home: ReceiptScannerScreen(
            ocrService: ocrService,
            picker: MockImagePicker(cancelled: true),
          ),
        ),
      );

      expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);
      expect(find.text('レシートを撮影'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('should show OCR result after capture', (tester) async {
      final ocrService = MockReceiptOcrService(
        mockText: 'ファミリーマート\n合計 ¥550',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ReceiptScannerScreen(
            ocrService: ocrService,
            picker: MockImagePicker(),
          ),
        ),
      );

      // 撮影ボタンをタップ
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      await tester.pump();

      // OCR結果を確認
      expect(find.text('📋 読み取り結果'), findsOneWidget);
      expect(find.text('ファミリーマート'), findsOneWidget);
      expect(find.text('¥550'), findsOneWidget);
    });

    testWidgets('should show retake and confirm buttons after OCR', (tester) async {
      final ocrService = MockReceiptOcrService(
        mockText: '合計 ¥300',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ReceiptScannerScreen(
            ocrService: ocrService,
            picker: MockImagePicker(),
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      await tester.pump();

      expect(find.text('撮り直す'), findsOneWidget);
      expect(find.text('この内容で記録'), findsOneWidget);
    });

    testWidgets('should show (未検出) for missing amount', (tester) async {
      final ocrService = MockReceiptOcrService(
        mockText: 'ありがとうございました',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ReceiptScannerScreen(
            ocrService: ocrService,
            picker: MockImagePicker(),
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      await tester.pump();

      // 金額は未検出
      expect(find.text('（未検出）'), findsAtLeast(1));
    });

    testWidgets('should show 再撮影 button text after first capture', (tester) async {
      final ocrService = MockReceiptOcrService(
        mockText: '合計 ¥100',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ReceiptScannerScreen(
            ocrService: ocrService,
            picker: MockImagePicker(),
          ),
        ),
      );

      // 最初は「レシートを撮影」
      expect(find.text('レシートを撮影'), findsOneWidget);

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      await tester.pump();

      // OCR後に「撮り直す」をタップしてリセット
      await tester.tap(find.text('撮り直す'));
      await tester.pump();

      // リセット後は「再撮影」に変わる
      expect(find.text('再撮影'), findsOneWidget);
    });

    testWidgets('should show AppBar with title', (tester) async {
      final ocrService = MockReceiptOcrService();

      await tester.pumpWidget(
        MaterialApp(
          home: ReceiptScannerScreen(
            ocrService: ocrService,
            picker: MockImagePicker(cancelled: true),
          ),
        ),
      );

      expect(find.text('レシート撮影'), findsOneWidget);
    });

    testWidgets('should handle camera cancel gracefully', (tester) async {
      final ocrService = MockReceiptOcrService();

      await tester.pumpWidget(
        MaterialApp(
          home: ReceiptScannerScreen(
            ocrService: ocrService,
            picker: MockImagePicker(cancelled: true),
          ),
        ),
      );

      // キャンセルしてもボタンはそのまま
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      await tester.pump();

      // 「レシートを撮影」のまま（OCR結果は表示されない）
      expect(find.text('レシートを撮影'), findsOneWidget);
      expect(find.text('📋 読み取り結果'), findsNothing);
    });
  });
}
