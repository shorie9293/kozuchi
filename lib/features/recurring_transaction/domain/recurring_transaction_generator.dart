import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/recurring_transaction/domain/recurring_transaction.dart';

/// 定期取引ジェネレータ
///
/// [RecurringTransaction] 定義から、指定時点までの発生分の
/// [TransactionModel] を生成する。純粋な計算のみを行い永続化はしない。
class RecurringTransactionGenerator {
  const RecurringTransactionGenerator();

  static const int _maxIterations = 100000;

  /// [recurring] の開始日から [now] までの発生分を生成する。
  ///
  /// 生成される日時は ISO 8601 形式（T12:00:00）。
  List<TransactionModel> generateFor(RecurringTransaction recurring, DateTime now) {
    final result = <TransactionModel>[];
    final nowDay = DateTime(now.year, now.month, now.day);

    var date = _firstOccurrenceOnOrAfter(recurring, recurring.startDate);
    if (date.isAfter(nowDay)) return result;

    while (!date.isAfter(nowDay)) {
      result.add(_toTransaction(recurring, date));
      date = _nextOccurrence(recurring, date);
      if (result.length > _maxIterations) break; // 安全弁
    }
    return result;
  }

  /// 開始日以降で最初の発生日を求める
  DateTime _firstOccurrenceOnOrAfter(RecurringTransaction r, DateTime from) {
    final day0 = DateTime(from.year, from.month, from.day);
    switch (r.frequency) {
      case RecurringFrequency.daily:
        return day0;
      case RecurringFrequency.weekly:
        var d = day0;
        while (d.weekday != r.dayOfWeek) {
          d = _addDays(d, 1);
        }
        return d;
      case RecurringFrequency.monthly:
        final firstOfMonth = DateTime(day0.year, day0.month, 1);
        final lastDay = DateTime(firstOfMonth.year, firstOfMonth.month + 1, 0).day;
        final day = r.dayOfMonth.clamp(1, lastDay);
        var occ = DateTime(firstOfMonth.year, firstOfMonth.month, day);
        if (occ.isBefore(day0)) {
          occ = _nextOccurrence(r, occ);
        }
        return occ;
    }
  }

  /// 次の発生日を求める
  DateTime _nextOccurrence(RecurringTransaction r, DateTime current) {
    switch (r.frequency) {
      case RecurringFrequency.daily:
        return _addDays(current, 1);
      case RecurringFrequency.weekly:
        return _addDays(current, 7);
      case RecurringFrequency.monthly:
        final nextMonthFirst = DateTime(current.year, current.month + 1, 1);
        final lastDay =
            DateTime(nextMonthFirst.year, nextMonthFirst.month + 1, 0).day;
        final day = r.dayOfMonth.clamp(1, lastDay);
        return DateTime(nextMonthFirst.year, nextMonthFirst.month, day);
    }
  }

  TransactionModel _toTransaction(RecurringTransaction r, DateTime date) {
    return TransactionModel(
      amount: r.amount,
      purpose: r.purpose,
      category: r.category,
      datetime: _iso(date),
    );
  }

  DateTime _addDays(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);

  String _iso(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-${day}T12:00:00';
  }
}
