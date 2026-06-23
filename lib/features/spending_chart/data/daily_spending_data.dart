/// 日別支出データモデル
///
/// 日別棒グラフコンポーネントの入力データ。
/// {day, amount} の配列として棒グラフに渡す。
class DailySpendingData {
  /// 日ラベル（例: "月", "火", "水" または "1", "2", "3"）
  final String day;

  /// 支出金額（円）
  final double amount;

  const DailySpendingData({
    required this.day,
    required this.amount,
  });

  @override
  String toString() => 'DailySpendingData(day: $day, amount: $amount)';
}
