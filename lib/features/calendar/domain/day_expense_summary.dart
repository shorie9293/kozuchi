import '../../../domain/models/expense_entry.dart';

/// 一日分の支出サマリ
///
/// [date] は 00:00:00 に正規化される。
/// [totalAmount] は [entries] の合計と一致しなければならない。
class DayExpenseSummary {
  /// 正規化済みの日付（時刻は 00:00:00）
  final DateTime date;

  /// その日の合計金額（>= 0）
  final int totalAmount;

  /// date 昇順 → 同時刻は id 昇順でソート済みの entries（非破壊コピー）
  final List<ExpenseEntry> entries;

  DayExpenseSummary({
    required DateTime date,
    required this.totalAmount,
    required List<ExpenseEntry> entries,
  })  : date = DateTime(date.year, date.month, date.day),
        entries = List.unmodifiable(
          List.of(entries)
            ..sort((a, b) {
              final byDate = a.date.compareTo(b.date);
              if (byDate != 0) return byDate;
              return a.id.compareTo(b.id);
            }),
        ) {
    if (totalAmount < 0) {
      throw ArgumentError('totalAmount must be >= 0');
    }
    var sum = 0;
    for (final entry in entries) {
      final entryDay = DateTime(entry.date.year, entry.date.month, entry.date.day);
      if (entryDay != this.date) {
        throw ArgumentError(
          'entry ${entry.id} date ${entry.date} is not on $date',
        );
      }
      sum += entry.amount;
    }
    if (sum != totalAmount) {
      throw ArgumentError(
        'totalAmount $totalAmount does not match entries sum $sum',
      );
    }
  }

  /// entries の件数
  int get entryCount => entries.length;

  /// 支出が 0 件か
  bool get isEmpty => entryCount == 0;

  /// 0 なら '' / それ以外は '¥1,234' 形式（3桁カンマ）
  String get amountLabel {
    if (totalAmount == 0) return '';
    final digits = totalAmount.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final remaining = digits.length - i;
      buffer.write(digits[i]);
      if (remaining > 1 && (remaining - 1) % 3 == 0) buffer.write(',');
    }
    return '¥$buffer';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DayExpenseSummary && runtimeType == other.runtimeType && date == other.date;

  @override
  int get hashCode => date.hashCode;

  @override
  String toString() =>
      'DayExpenseSummary(date: $date, totalAmount: $totalAmount, entries: $entryCount)';
}
