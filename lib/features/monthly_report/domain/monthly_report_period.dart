/// 月次レポートの対象期間（暦月1か月）
///
/// 不変。年月のみを保持し、月末日や前後月の計算を提供する。
class MonthlyReportPeriod {
  final int year;
  final int month;

  /// [month] は 1..12、[year] は 1970 以上であること。
  MonthlyReportPeriod({required this.year, required this.month}) {
    if (month < 1 || month > 12) {
      throw ArgumentError.value(month, 'month', 'month must be 1..12');
    }
    if (year < 1970) {
      throw ArgumentError.value(year, 'year', 'year must be >= 1970');
    }
  }

  /// 日付から同月の期間を作る
  static MonthlyReportPeriod fromDate(DateTime d) =>
      MonthlyReportPeriod(year: d.year, month: d.month);

  /// 月初（1日 0時）
  DateTime get start => DateTime(year, month, 1);

  /// 月末日（翌月1日から1日引く）
  DateTime get end =>
      DateTime(year, month + 1, 1).subtract(const Duration(days: 1));

  /// 前月（1月なら前年12月）
  MonthlyReportPeriod get previous => month == 1
      ? MonthlyReportPeriod(year: year - 1, month: 12)
      : MonthlyReportPeriod(year: year, month: month - 1);

  /// 翌月（12月なら翌年1月）
  MonthlyReportPeriod get next => month == 12
      ? MonthlyReportPeriod(year: year + 1, month: 1)
      : MonthlyReportPeriod(year: year, month: month + 1);

  /// [d] がこの月内か（日単位・時刻無視）
  bool contains(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  /// 表示ラベル（例: 2026年9月）
  String get label => '$year年$month月';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonthlyReportPeriod &&
          runtimeType == other.runtimeType &&
          year == other.year &&
          month == other.month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => 'MonthlyReportPeriod($year-$month)';
}
