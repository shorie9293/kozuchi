import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/income/domain/models/income_entry.dart';
import 'package:kozuchi/features/monthly_report/domain/monthly_report_period.dart';

/// 収入(IncomeEntry)を符号付き取引へ合流させる純粋ロジック（I/O 無し）
class IncomeTransactionMerger {
  IncomeTransactionMerger._();

  /// 収入1件 → amount が正の [TransactionModel]
  ///
  /// - amount: 収入額そのまま（[IncomeEntry] の検証により常に正）
  /// - purpose: note があれば note、無ければ source
  /// - category: source
  /// - datetime: date の ISO 8601 文字列
  static TransactionModel toTransaction(IncomeEntry entry) {
    return TransactionModel(
      amount: entry.amount,
      purpose: entry.note ?? entry.source,
      category: entry.source,
      datetime: entry.date.toIso8601String(),
    );
  }

  /// 期間内の収入のみを返す（元リスト非破壊）
  ///
  /// 期間判定は [MonthlyReportPeriod.contains] に委ねる（日単位・両端含む）。
  /// すなわち start 当日 0時〜end 当日の任意時刻までが対象となる。
  static List<IncomeEntry> within(
    List<IncomeEntry> entries,
    MonthlyReportPeriod period,
  ) {
    return entries.where((e) => period.contains(e.date)).toList();
  }

  /// 支出取引列（負の符号付き）に、期間内の収入を正の取引として合流させる。
  ///
  /// 支出側の順序を保持し、収入はその後ろに date 昇順で並べる。
  /// 同一日時の収入は入力順を保つ。元リストは非破壊。
  static List<TransactionModel> merge({
    required List<TransactionModel> expenses,
    required List<IncomeEntry> incomes,
    required MonthlyReportPeriod period,
  }) {
    final adopted = within(incomes, period);
    // List.sort は安定でないため、元インデックスを第2キーにして安定化する。
    final indexed = adopted.asMap().entries.toList()
      ..sort((a, b) {
        final cmp = a.value.date.compareTo(b.value.date);
        if (cmp != 0) return cmp;
        return a.key.compareTo(b.key);
      });

    return <TransactionModel>[
      ...expenses,
      for (final e in indexed) toTransaction(e.value),
    ];
  }
}
