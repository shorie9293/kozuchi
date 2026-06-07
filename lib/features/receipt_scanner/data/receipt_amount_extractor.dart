/// OCRテキストからレシート情報を抽出する
///
/// レシートのOCR結果テキストから、合計金額と店名を抽出する。
class ReceiptAmountExtractor {
  /// 金額の前に現れる典型的なキーワード（優先度順）
  static const _amountPrefixes = [
    '合計金額',
    '合計',
    'お支払い',
    '小計',
  ];

  /// 抽出結果
  ReceiptExtractResult extract(String text) {
    return ReceiptExtractResult(
      storeName: _extractStoreName(text),
      amount: _extractAmount(text),
    );
  }

  /// 店名を抽出（最初の有意味な行）
  String? _extractStoreName(String text) {
    if (text.isEmpty) return null;

    final lines = text.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }

  /// 合計金額を抽出
  int? _extractAmount(String text) {
    // 優先度順に探す（合計 > 小計）
    for (final prefix in _amountPrefixes) {
      final amount = _tryExtractWithPrefix(text, prefix);
      if (amount != null) return amount;
    }
    return null;
  }

  /// 特定のプレフィックスで金額を抽出
  int? _tryExtractWithPrefix(String text, String prefix) {
    final pattern = RegExp(
      '${RegExp.escape(prefix)}\\s*[¥￥]?\\s*([\\d,]+)\\s*円?',
      multiLine: true,
    );
    final match = pattern.firstMatch(text);
    if (match == null) return null;

    final amountStr = match.group(1)!;
    final cleaned = amountStr.replaceAll(',', '');
    return int.tryParse(cleaned);
  }
}

/// レシート抽出結果
class ReceiptExtractResult {
  final String? storeName;
  final int? amount;

  ReceiptExtractResult({
    this.storeName,
    this.amount,
  });
}
