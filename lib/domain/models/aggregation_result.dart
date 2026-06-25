/// カテゴリ別集計エントリ
class CategoryTotal {
  final String category;
  final int amount;
  final double percentage; // 0.0〜100.0

  const CategoryTotal({
    required this.category,
    required this.amount,
    required this.percentage,
  });

  Map<String, dynamic> toJson() => {
        'category': category,
        'amount': amount,
        'percentage': percentage,
      };

  @override
  String toString() =>
      'CategoryTotal($category: ¥$amount, ${percentage.toStringAsFixed(1)}%)';
}

/// 日別集計エントリ
class DailyTotal {
  final DateTime date;
  final int amount;

  const DailyTotal({required this.date, required this.amount});

  Map<String, dynamic> toJson() => {
        'date': _formatDate(date),
        'amount': amount,
      };

  static String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  String toString() => 'DailyTotal(${_formatDate(date)}: ¥$amount)';
}

/// 期間情報
class PeriodInfo {
  final DateTime start;
  final DateTime end;
  final String type; // 'weekly' or 'monthly'

  const PeriodInfo({
    required this.start,
    required this.end,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
        'start': DailyTotal._formatDate(start),
        'end': DailyTotal._formatDate(end),
        'type': type,
      };

  @override
  String toString() => 'PeriodInfo($type: ${DailyTotal._formatDate(start)} ~ ${DailyTotal._formatDate(end)})';
}

/// 期間集計データ
class PeriodAggregation {
  final int total;
  final List<CategoryTotal> byCategory;
  final List<DailyTotal> byDay;

  const PeriodAggregation({
    required this.total,
    required this.byCategory,
    required this.byDay,
  });

  Map<String, dynamic> toJson() => {
        'total': total,
        'byCategory': byCategory.map((c) => c.toJson()).toList(),
        'byDay': byDay.map((d) => d.toJson()).toList(),
      };

  @override
  String toString() =>
      'PeriodAggregation(total: ¥$total, categories: ${byCategory.length}, days: ${byDay.length})';
}

/// カテゴリ別前期間比較
class CategoryComparison {
  final String category;
  final int currentAmount;
  final int previousAmount;
  final int change;
  final double changePercent; // 正=増加, 負=減少

  const CategoryComparison({
    required this.category,
    required this.currentAmount,
    required this.previousAmount,
    required this.change,
    required this.changePercent,
  });

  Map<String, dynamic> toJson() => {
        'category': category,
        'currentAmount': currentAmount,
        'previousAmount': previousAmount,
        'change': change,
        'changePercent': changePercent,
      };

  @override
  String toString() =>
      'CategoryComparison($category: ¥$currentAmount vs ¥$previousAmount, ${change >= 0 ? "+" : ""}$change)';
}

/// 期間比較データ
class PeriodComparison {
  final int totalChange;
  final double totalChangePercent;
  final List<CategoryComparison> byCategoryChanges;

  const PeriodComparison({
    required this.totalChange,
    required this.totalChangePercent,
    required this.byCategoryChanges,
  });

  Map<String, dynamic> toJson() => {
        'totalChange': totalChange,
        'totalChangePercent': totalChangePercent,
        'byCategoryChanges':
            byCategoryChanges.map((c) => c.toJson()).toList(),
      };

  @override
  String toString() =>
      'PeriodComparison(totalChange: ${totalChange >= 0 ? "+" : ""}$totalChange, ${totalChangePercent >= 0 ? "+" : ""}${totalChangePercent.toStringAsFixed(1)}%)';
}

/// 集計結果（トップレベル）
///
/// ExpenseAggregationService が返す完全な集計結果。
/// 現在期間・前期間・比較の3ブロックからなる。
class AggregationResult {
  final PeriodInfo period;
  final PeriodInfo previousPeriod;
  final PeriodAggregation current;
  final PeriodAggregation previous;
  final PeriodComparison comparison;

  const AggregationResult({
    required this.period,
    required this.previousPeriod,
    required this.current,
    required this.previous,
    required this.comparison,
  });

  /// 構造化JSONに変換
  Map<String, dynamic> toJson() => {
        'period': period.toJson(),
        'previousPeriod': previousPeriod.toJson(),
        'current': current.toJson(),
        'previous': previous.toJson(),
        'comparison': comparison.toJson(),
      };

  @override
  String toString() =>
      'AggregationResult(${period.type}: current=¥${current.total}, previous=¥${previous.total}, change=${comparison.totalChange >= 0 ? "+" : ""}${comparison.totalChange})';
}
