import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/monthly_report/domain/monthly_report.dart';
import 'package:kozuchi/features/monthly_report/domain/monthly_report_period.dart';

/// 月次レポート構築サービス（純粋ロジック・I/O無し）
class MonthlyReportService {
  MonthlyReportService._();

  /// [transactions]（当月候補）と [previousMonthTransactions]（前月候補）から
  /// 月次レポートを組み立てる。
  ///
  /// 無視ルール:
  /// - datetime が空・パース不能な取引
  /// - period に含まれない取引
  /// - amount == 0 の取引（収入にも支出にも数えない）
  ///
  /// [previousMonthTransactions] を渡さなかった場合のみ
  /// previousTotalExpense が null になる（空リストを渡せば 0）。
  static MonthlyReport build({
    required MonthlyReportPeriod period,
    required List<TransactionModel> transactions,
    List<TransactionModel>? previousMonthTransactions,
  }) {
    final adopted = _adopt(transactions, period);
    final totalIncome = adopted
        .where((t) => t.amount > 0)
        .fold(0, (sum, t) => sum + t.amount);
    final totalExpense = adopted
        .where((t) => t.amount < 0)
        .fold(0, (sum, t) => sum + t.amount.abs());
    final transactionCount = adopted.length;

    final categories = _buildCategories(adopted, totalExpense);

    int? previousTotalExpense;
    int? expenseChange;
    double? expenseChangePercent;
    if (previousMonthTransactions != null) {
      final prev = _adopt(previousMonthTransactions, period.previous);
      final prevExpense = prev
          .where((t) => t.amount < 0)
          .fold(0, (sum, t) => sum + t.amount.abs());
      previousTotalExpense = prevExpense;
      expenseChange = totalExpense - prevExpense;
      expenseChangePercent =
          prevExpense > 0 ? (expenseChange / prevExpense) * 100 : null;
    }

    final balance = totalIncome - totalExpense;
    final savingsRate =
        totalIncome > 0 ? (balance / totalIncome).clamp(0.0, 1.0) : 0.0;

    return MonthlyReport(
      period: period,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      transactionCount: transactionCount,
      categories: categories,
      previousTotalExpense: previousTotalExpense,
      expenseChange: expenseChange,
      expenseChangePercent: expenseChangePercent,
      savingsRate: savingsRate,
    );
  }

  /// 期間内かつパース可能な取引のみ採用する（元リストは非破壊）
  static List<TransactionModel> _adopt(
    List<TransactionModel> transactions,
    MonthlyReportPeriod period,
  ) {
    final result = <TransactionModel>[];
    for (final t in transactions) {
      if (t.amount == 0) continue;
      final dt = _parse(t.datetime);
      if (dt == null) continue;
      if (!period.contains(dt)) continue;
      result.add(t);
    }
    return result;
  }

  /// datetime 文字列をパース（空・不能なら null）
  static DateTime? _parse(String datetime) {
    if (datetime.isEmpty) return null;
    return DateTime.tryParse(datetime);
  }

  /// 支出カテゴリ別集計（支出降順 -> カテゴリ名昇順）
  static List<MonthlyReportCategory> _buildCategories(
    List<TransactionModel> adopted,
    int totalExpense,
  ) {
    final byCategory = <String, int>{};
    for (final t in adopted) {
      if (t.amount >= 0) continue;
      final key = t.category.isEmpty ? 'その他' : t.category;
      byCategory[key] = (byCategory[key] ?? 0) + t.amount.abs();
    }
    final entries = byCategory.entries.toList()
      ..sort((a, b) {
        final cmp = b.value.compareTo(a.value);
        if (cmp != 0) return cmp;
        return a.key.compareTo(b.key);
      });
    return entries
        .map((e) => MonthlyReportCategory(
              category: e.key,
              amount: e.value,
              ratio: totalExpense > 0 ? e.value / totalExpense : 0.0,
            ))
        .toList();
  }
}
