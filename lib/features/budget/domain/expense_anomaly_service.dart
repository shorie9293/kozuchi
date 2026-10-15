import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/features/budget/domain/expense_anomaly.dart';

/// 支出の異常検知を行うサービス
///
/// 純粋ロジックのみ。DateTime.now() を内部で呼ばない。I/O 禁止。
class ExpenseAnomalyService {
  /// これ以上の ratio で異常（elevated）
  static const double defaultElevatedRatio = 2.0;

  /// これ以上の ratio で high
  static const double defaultHighRatio = 3.0;

  /// 過去サンプル数の下限（これ未満なら判定しない）
  static const int defaultMinSamples = 3;

  const ExpenseAnomalyService();

  /// カテゴリ正規化: trim し、空なら「未分類」
  static String normalizeCategory(String category) {
    final trimmed = category.trim();
    return trimmed.isEmpty ? '未分類' : trimmed;
  }

  /// 1件の候補支出が過去履歴から外れているか判定。異常でなければ null。
  ExpenseAnomaly? detect({
    required ExpenseEntry candidate,
    required Iterable<ExpenseEntry> history,
    double elevatedRatio = defaultElevatedRatio,
    double highRatio = defaultHighRatio,
    int minSamples = defaultMinSamples,
  }) {
    if (candidate.amount <= 0) return null;
    final category = normalizeCategory(candidate.category);

    final samples = <int>[];
    for (final entry in history) {
      if (entry.id == candidate.id) continue;
      if (entry.amount <= 0) continue;
      if (normalizeCategory(entry.category) != category) continue;
      samples.add(entry.amount);
    }

    if (samples.length < minSamples) return null;
    if (samples.isEmpty) return null;

    final total = samples.fold<int>(0, (sum, a) => sum + a);
    final average = total / samples.length;
    if (average <= 0) return null;

    final ratio = candidate.amount / average;
    if (ratio < elevatedRatio) return null;

    final level =
        ratio >= highRatio ? AnomalyLevel.high : AnomalyLevel.elevated;

    return ExpenseAnomaly(
      entry: candidate,
      category: category,
      amount: candidate.amount,
      average: average,
      ratio: ratio,
      sampleCount: samples.length,
      level: level,
    );
  }

  /// エントリ群の中で、他の履歴と比較して異常なもののみを抽出。
  /// 結果は entry.date 降順、同時刻は entry.id 昇順の安定ソート。
  List<ExpenseAnomaly> detectAll(
    Iterable<ExpenseEntry> entries, {
    double elevatedRatio = defaultElevatedRatio,
    double highRatio = defaultHighRatio,
    int minSamples = defaultMinSamples,
  }) {
    final list = entries.toList(growable: false);
    final results = <ExpenseAnomaly>[];
    for (final entry in list) {
      final anomaly = detect(
        candidate: entry,
        history: list,
        elevatedRatio: elevatedRatio,
        highRatio: highRatio,
        minSamples: minSamples,
      );
      if (anomaly != null) results.add(anomaly);
    }
    results.sort((a, b) {
      final byDate = b.entry.date.compareTo(a.entry.date);
      if (byDate != 0) return byDate;
      return a.entry.id.compareTo(b.entry.id);
    });
    return results;
  }

  /// カテゴリ別平均額（amount>0のみ対象、category空は「未分類」に寄せる）。
  Map<String, double> categoryAverages(Iterable<ExpenseEntry> entries) {
    final totals = <String, int>{};
    final counts = <String, int>{};
    for (final entry in entries) {
      if (entry.amount <= 0) continue;
      final category = normalizeCategory(entry.category);
      totals[category] = (totals[category] ?? 0) + entry.amount;
      counts[category] = (counts[category] ?? 0) + 1;
    }
    return {
      for (final key in totals.keys)
        key: totals[key]! / counts[key]!,
    };
  }
}