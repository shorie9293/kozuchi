import '../models/expense_entry.dart';
import '../models/aggregation_result.dart';
import 'expense_repository.dart';

/// 支出データ集計サービス
///
/// 週間・月間の支出を集計し、カテゴリ別・日別の集計と
/// 前期間との比較データを生成する。
class ExpenseAggregationService {
  final ExpenseRepository _repository;

  /// デフォルトの支出カテゴリ一覧
  static const List<String> defaultCategories = [
    '食費',
    '交通費',
    '娯楽',
    '住居費',
    '光熱費',
    '医療費',
    '教育費',
    '交際費',
    '衣服費',
    '通信費',
    '日用品',
    'その他',
  ];

  const ExpenseAggregationService(this._repository);

  /// 週間集計を取得する
  ///
  /// [referenceDate] を含む週（月曜始まり〜日曜終わり）を現在期間として集計。
  /// その前週を前期間として比較データを生成する。
  Future<AggregationResult> getWeeklySummary(DateTime referenceDate) async {
    final weekStart = _weekStart(referenceDate);
    final weekEnd = weekStart.add(const Duration(days: 6));
    final prevWeekStart = weekStart.subtract(const Duration(days: 7));
    final prevWeekEnd = weekStart.subtract(const Duration(days: 1));

    return _buildAggregation(
      start: weekStart,
      end: weekEnd,
      prevStart: prevWeekStart,
      prevEnd: prevWeekEnd,
      type: 'weekly',
    );
  }

  /// 月間集計を取得する
  ///
  /// [referenceDate] を含む月（1日〜月末）を現在期間として集計。
  /// その前月を前期間として比較データを生成する。
  Future<AggregationResult> getMonthlySummary(DateTime referenceDate) async {
    final monthStart = DateTime(referenceDate.year, referenceDate.month, 1);
    final monthEnd = DateTime(referenceDate.year, referenceDate.month + 1, 0);
    final prevMonthStart = DateTime(referenceDate.year, referenceDate.month - 1, 1);
    final prevMonthEnd = DateTime(referenceDate.year, referenceDate.month, 0);

    return _buildAggregation(
      start: monthStart,
      end: monthEnd,
      prevStart: prevMonthStart,
      prevEnd: prevMonthEnd,
      type: 'monthly',
    );
  }

  /// 集計のコアロジック
  Future<AggregationResult> _buildAggregation({
    required DateTime start,
    required DateTime end,
    required DateTime prevStart,
    required DateTime prevEnd,
    required String type,
  }) async {
    // 現在期間と前期間のエントリを並列取得（効率化）
    final results = await Future.wait([
      _repository.getEntries(start: start, end: end),
      _repository.getEntries(start: prevStart, end: prevEnd),
    ]);

    final currentEntries = results[0];
    final previousEntries = results[1];

    // 現在期間の集計
    final currentAgg = _aggregatePeriod(currentEntries);

    // 前期間の集計
    final previousAgg = _aggregatePeriod(previousEntries);

    // 比較データ生成
    final comparison = _buildComparison(currentAgg, previousAgg);

    return AggregationResult(
      period: PeriodInfo(start: start, end: end, type: type),
      previousPeriod:
          PeriodInfo(start: prevStart, end: prevEnd, type: type),
      current: currentAgg,
      previous: previousAgg,
      comparison: comparison,
    );
  }

  /// 単一期間の集計
  PeriodAggregation _aggregatePeriod(List<ExpenseEntry> entries) {
    // 総額
    final total = entries.fold<int>(0, (sum, e) => sum + e.amount);

    // カテゴリ別集計
    final categoryMap = <String, int>{};
    for (final entry in entries) {
      categoryMap[entry.category] =
          (categoryMap[entry.category] ?? 0) + entry.amount;
    }

    final byCategory = categoryMap.entries
        .map((e) => CategoryTotal(
              category: e.key,
              amount: e.value,
              percentage: total > 0 ? (e.value / total) * 100.0 : 0.0,
            ))
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount)); // 金額降順

    // 日別集計
    final dayMap = <DateTime, int>{};
    for (final entry in entries) {
      final day = _dayOnly(entry.date);
      dayMap[day] = (dayMap[day] ?? 0) + entry.amount;
    }

    final byDay = dayMap.entries
        .map((e) => DailyTotal(date: e.key, amount: e.value))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date)); // 日付昇順

    return PeriodAggregation(
      total: total,
      byCategory: byCategory,
      byDay: byDay,
    );
  }

  /// 前期間との比較データを生成
  PeriodComparison _buildComparison(
    PeriodAggregation current,
    PeriodAggregation previous,
  ) {
    // 総額の変化
    final totalChange = current.total - previous.total;
    final totalChangePercent = previous.total > 0
        ? (totalChange / previous.total) * 100.0
        : (current.total > 0 ? 100.0 : 0.0);

    // カテゴリ別の変化
    // 現在と前期間の全カテゴリを収集
    final allCategories = <String>{};
    for (final c in current.byCategory) {
      allCategories.add(c.category);
    }
    for (final c in previous.byCategory) {
      allCategories.add(c.category);
    }

    final prevMap = <String, int>{};
    for (final c in previous.byCategory) {
      prevMap[c.category] = c.amount;
    }

    final byCategoryChanges = <CategoryComparison>[];
    for (final cat in allCategories) {
      final currentAmount =
          current.byCategory.where((c) => c.category == cat).fold<int>(
                0,
                (sum, c) => sum + c.amount,
              );
      final previousAmount = prevMap[cat] ?? 0;
      final change = currentAmount - previousAmount;
      final changePercent = previousAmount > 0
          ? (change / previousAmount) * 100.0
          : (currentAmount > 0 ? 100.0 : 0.0);

      byCategoryChanges.add(CategoryComparison(
        category: cat,
        currentAmount: currentAmount,
        previousAmount: previousAmount,
        change: change,
        changePercent: changePercent,
      ));
    }
    byCategoryChanges.sort((a, b) => b.change.abs().compareTo(a.change.abs()));

    return PeriodComparison(
      totalChange: totalChange,
      totalChangePercent: totalChangePercent,
      byCategoryChanges: byCategoryChanges,
    );
  }

  /// 日付から時刻を除去（日単位の比較用）
  DateTime _dayOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  /// 週の開始日（月曜日）を返す
  DateTime _weekStart(DateTime date) {
    final dayOnly = _dayOnly(date);
    // DateTime.weekday: 1=Mon, 7=Sun
    final daysFromMonday = dayOnly.weekday - 1;
    return dayOnly.subtract(Duration(days: daysFromMonday));
  }
}
