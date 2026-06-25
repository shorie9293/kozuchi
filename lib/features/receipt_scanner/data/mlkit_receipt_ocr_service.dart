import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'receipt_ocr_service.dart';
import 'receipt_amount_extractor.dart';

/// Google ML Kit を用いた実レシートOCRサービス
///
/// カメラで撮影したレシート画像からテキストを抽出し、
/// 金額と店名を自動抽出する。
class MlKitReceiptOcrService implements ReceiptOcrService {
  final TextRecognizer _textRecognizer;
  final ReceiptAmountExtractor _extractor;

  MlKitReceiptOcrService({
    TextRecognizer? textRecognizer,
    ReceiptAmountExtractor? extractor,
  })  : _textRecognizer = textRecognizer ?? TextRecognizer(script: TextRecognitionScript.latin),
        _extractor = extractor ?? ReceiptAmountExtractor();

  @override
  Future<ReceiptOcrResult> processImage(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      return ReceiptOcrResult(
        rawText: '',
        storeName: null,
        amount: null,
        imagePath: imagePath,
      );
    }

    final inputImage = InputImage.fromFilePath(imagePath);
    final recognisedText = await _textRecognizer.processImage(inputImage);

    final rawText = recognisedText.text;
    final extractResult = _extractor.extract(rawText);

    return ReceiptOcrResult(
      rawText: rawText,
      storeName: extractResult.storeName,
      amount: extractResult.amount,
      imagePath: imagePath,
    );
  }

  /// リソースを解放する
  Future<void> dispose() async {
    await _textRecognizer.close();
  }
}
