import 'package:kozuchi/features/monthly_report/domain/monthly_report_period.dart';

/// 月次レポートのカテゴリ別集計
///
/// 不変。[amount] は 0 以上、[ratio] は 0.0..1.0。
class MonthlyReportCategory {
  final String category;
  final int amount;

  /// 支出合計に占める割合（0.0..1.0）
  final double ratio;

  const MonthlyReportCategory({
    required this.category,
    required this.amount,
    required this.ratio,
  })  : assert(amount >= 0),
        assert(ratio >= 0.0 && ratio <= 1.0);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonthlyReportCategory &&
          runtimeType == other.runtimeType &&
          category == other.category &&
          amount == other.amount &&
          ratio == other.ratio;

  @override
  int get hashCode => Object.hash(category, amount, ratio);

  @override
  String toString() =>
      'MonthlyReportCategory($category, $amount, ${(ratio * 100).toStringAsFixed(1)}%)';
}

/// 月次家計レポート
///
/// 不変。収入・支出・収支・カテゴリ別集計・前月比・貯蓄率を保持する。
class MonthlyReport {
  final MonthlyReportPeriod period;
  final int totalIncome;
  final int totalExpense;

  /// 収支（totalIncome - totalExpense）
  final int balance;
  final int transactionCount;
  final List<MonthlyReportCategory> categories;

  /// 前月支出合計（前月データが無い場合は null）
  final int? previousTotalExpense;
  final int? expenseChange;
  final double? expenseChangePercent;

  /// 貯蓄率（0.0..1.0、収入0なら 0.0）
  final double savingsRate;

  MonthlyReport({
    required this.period,
    required this.totalIncome,
    required this.totalExpense,
    required this.transactionCount,
    required this.categories,
    this.previousTotalExpense,
    this.expenseChange,
    this.expenseChangePercent,
    double? savingsRate,
  })  : assert(totalIncome >= 0),
        assert(totalExpense >= 0),
        balance = totalIncome - totalExpense,
        savingsRate = savingsRate == null
            ? 0.0
            : (savingsRate.isNaN ? 0.0 : savingsRate.clamp(0.0, 1.0));

  /// 取引が1件も無い月か
  bool get isEmpty => transactionCount == 0;

  /// 前月比ラベル
  ///
  /// 前月データなし -> '先月データなし'
  /// 変化率 1%未満 -> '先月とほぼ同じ'
  /// 減少 -> '-12.3%' 形式 / 増加 -> '+12.3%' 形式
  String get changeLabel {
    final percent = expenseChangePercent;
    if (previousTotalExpense == null || percent == null) {
      return '先月データなし';
    }
    if (percent.abs() < 1.0) {
      return '先月とほぼ同じ';
    }
    if (percent < 0) {
      return '-${percent.abs().toStringAsFixed(1)}%';
    }
    return '+${percent.toStringAsFixed(1)}%';
  }

  /// 貯蓄率ラベル（例: 貯蓄率 25.0%）
  String get savingsRateLabel =>
      '貯蓄率 ${(savingsRate * 100).toStringAsFixed(1)}%';

  /// 上位 [n] カテゴリ（すでに降順ソート済みの先頭 n 件）
  ///
  /// [n] が 1 未満なら ArgumentError、件数を超えていれば全件。
  List<MonthlyReportCategory> topCategories(int n) {
    if (n < 1) {
      throw ArgumentError.value(n, 'n', 'n must be >= 1');
    }
    if (categories.length <= n) {
      return List<MonthlyReportCategory>.unmodifiable(categories);
    }
    return List<MonthlyReportCategory>.unmodifiable(
      categories.sublist(0, n),
    );
  }

  /// 共有用テキスト（複数行）
  String get shareText {
    if (isEmpty) {
      return '${period.label} 家計レポート\nこの月の記録はありません';
    }
    final buf = StringBuffer();
    buf.writeln('${period.label} 家計レポート');
    buf.writeln('収入: $totalIncome円');
    buf.writeln('支出: $totalExpense円');
    buf.writeln('収支: ${balance >= 0 ? '+' : ''}$balance円');
    buf.writeln(savingsRateLabel);
    buf.writeln('前月比: $changeLabel');
    final top = topCategories(3);
    if (top.isNotEmpty) {
      buf.writeln('TOPカテゴリ:');
      for (final c in top) {
        buf.writeln('- ${c.category}: ${c.amount}円'
            ' (${(c.ratio * 100).toStringAsFixed(1)}%)');
      }
    }
    return buf.toString().trimRight();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonthlyReport &&
          runtimeType == other.runtimeType &&
          period == other.period &&
          totalIncome == other.totalIncome &&
          totalExpense == other.totalExpense &&
          transactionCount == other.transactionCount &&
          previousTotalExpense == other.previousTotalExpense &&
          savingsRate == other.savingsRate &&
          _listEquals(categories, other.categories);

  @override
  int get hashCode => Object.hash(period, totalIncome, totalExpense,
      transactionCount, previousTotalExpense, savingsRate);

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
