/// 収入源別の集計結果を表すモデル。
class IncomeSourceSummary {
  /// 収入源の表示名（初出時の表記）
  final String source;

  /// 正規化済みの収入源キー
  final String normalizedSource;

  /// 合計金額（円）
  final int amount;

  /// 記録件数
  final int count;

  /// 構成比（0.0〜1.0）。全収入が0の場合は 0。
  final double ratio;

  const IncomeSourceSummary({
    required this.source,
    required this.normalizedSource,
    required this.amount,
    required this.count,
    required this.ratio,
  });

  /// 構成比の表示ラベル（例: `62%`）。四捨五入。
  String get ratioLabel => '${(ratio * 100).round()}%';

  /// 金額の表示ラベル（例: `¥62,000`）。3桁カンマ区切り。
  String get amountLabel {
    final digits = amount.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);
      final remaining = digits.length - i - 1;
      if (remaining > 0 && remaining % 3 == 0) buffer.write(',');
    }
    return '¥$buffer';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IncomeSourceSummary &&
          runtimeType == other.runtimeType &&
          source == other.source &&
          amount == other.amount &&
          count == other.count &&
          ratio == other.ratio;

  @override
  int get hashCode => Object.hash(source, amount, count, ratio);
}
