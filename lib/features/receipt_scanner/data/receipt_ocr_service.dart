import 'receipt_amount_extractor.dart';

/// レシートOCRの結果
class ReceiptOcrResult {
  /// OCRで抽出された生テキスト
  final String rawText;

  /// 抽出された店名
  final String? storeName;

  /// 抽出された合計金額
  final int? amount;

  /// 画像のファイルパス
  final String imagePath;

  ReceiptOcrResult({
    required this.rawText,
    this.storeName,
    this.amount,
    required this.imagePath,
  });
}

/// レシートOCRサービスインターフェース
///
/// 実装は google_mlkit_text_recognition 等を用いる。
/// テストではモック実装に差し替え可能。
abstract class ReceiptOcrService {
  /// 画像パスからOCRを実行し、結果を返す
  Future<ReceiptOcrResult> processImage(String imagePath);
}

/// テスト用のモックOCRサービス実装
///
/// 与えられたテキストをそのままOCR結果として返す。
class MockReceiptOcrService implements ReceiptOcrService {
  final ReceiptAmountExtractor _extractor = ReceiptAmountExtractor();

  /// モック用の固定テキスト（nullの場合はレベルMAX文字列として扱う）
  final String? mockText;

  MockReceiptOcrService({this.mockText});

  @override
  Future<ReceiptOcrResult> processImage(String imagePath) async {
    final text = mockText ?? '';
    final extractResult = _extractor.extract(text);

    return ReceiptOcrResult(
      rawText: text,
      storeName: extractResult.storeName,
      amount: extractResult.amount,
      imagePath: imagePath,
    );
  }
}
