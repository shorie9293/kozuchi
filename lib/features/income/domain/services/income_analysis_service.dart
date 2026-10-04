import '../models/income_entry.dart';
import '../models/income_source_summary.dart';

/// 収入源別の内訳を集計する純粋サービス。
///
/// [ExpenseAggregationService]（支出版）と対になる。
/// 画面・リポジトリに依存せず、[IncomeEntry] のリストから集計する。
class IncomeAnalysisService {
  const IncomeAnalysisService._();

  /// 収入源の正規化（照合キー生成）。
  ///
  /// 全角英数・全角スペース → 半角、前後空白の除去、
  /// 連続空白の圧縮、小文字化。
  static String normalizeSource(String source) {
    var normalized = source;
    // 全角英数字 → 半角
    normalized = normalized.replaceAllMapped(
      RegExp(r'[Ａ-Ｚａ-ｚ０-９]'),
      (m) => String.fromCharCode(m[0]!.runes.first - 0xFEE0),
    );
    // 全角スペース → 半角
    normalized = normalized.replaceAll('\u3000', ' ');
    normalized = normalized.trim();
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');
    return normalized.toLowerCase();
  }

  /// 収入源別の集計（合計金額・件数・構成比）。
  ///
  /// - 正規化キーが同一の収入源は同一グループに集計される
  /// - 表示名は**初出の表記**を採用する（宣言順保持）
  /// - 並び順は金額降順 → 正規化キー昇順（非破壊）
  /// - amount が 0 以下のエントリと空の収入源は無視する
  static List<IncomeSourceSummary> aggregateBySource(
    List<IncomeEntry> entries,
  ) {
    final valid = entries.where((e) {
      if (e.amount <= 0) return false;
      if (normalizeSource(e.source).isEmpty) return false;
      return true;
    }).toList();

    final total = valid.fold<int>(0, (sum, e) => sum + e.amount);
    if (valid.isEmpty || total <= 0) return const [];

    // 正規化キー → 初出の表記
    final displayNames = <String, String>{};
    final amounts = <String, int>{};
    final counts = <String, int>{};
    for (final entry in valid) {
      final key = normalizeSource(entry.source);
      displayNames.putIfAbsent(key, () => entry.source);
      amounts[key] = (amounts[key] ?? 0) + entry.amount;
      counts[key] = (counts[key] ?? 0) + 1;
    }

    final summaries = [
      for (final key in amounts.keys)
        IncomeSourceSummary(
          source: displayNames[key]!,
          normalizedSource: key,
          amount: amounts[key]!,
          count: counts[key]!,
          ratio: amounts[key]! / total,
        ),
    ];

    final sorted = [...summaries];
    sorted.sort((a, b) {
      if (a.amount != b.amount) return b.amount - a.amount;
      return a.normalizedSource.compareTo(b.normalizedSource);
    });
    return sorted;
  }

  /// 収入の合計金額。
  static int totalAmount(List<IncomeEntry> entries) =>
      entries.fold<int>(0, (sum, e) => sum + (e.amount > 0 ? e.amount : 0));

  /// 収入の記録件数（有効なもののみ）。
  static int entryCount(List<IncomeEntry> entries) => entries
      .where((e) => e.amount > 0 && normalizeSource(e.source).isNotEmpty)
      .length;

  /// 構成比首位の収入源（空なら null）。
  static IncomeSourceSummary? topSource(List<IncomeEntry> entries) {
    final summaries = aggregateBySource(entries);
    return summaries.isEmpty ? null : summaries.first;
  }

  /// 期間で絞り込む（start 以上 end 以下・日単位）。
  static List<IncomeEntry> filterByPeriod(
    List<IncomeEntry> entries, {
    required DateTime start,
    required DateTime end,
  }) {
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    return entries.where((e) {
      final day = DateTime(e.date.year, e.date.month, e.date.day);
      return !day.isBefore(startDay) && !day.isAfter(endDay);
    }).toList();
  }

  /// 収入源で検索する（正規化した部分一致・非破壊）。
  ///
  /// 空クエリ・空白のみは全件を返す。
  static List<IncomeEntry> searchBySource(
    List<IncomeEntry> entries,
    String query,
  ) {
    final normalizedQuery = normalizeSource(query);
    if (normalizedQuery.isEmpty) return [...entries];
    return entries
        .where((e) => normalizeSource(e.source).contains(normalizedQuery))
        .toList();
  }

  /// 分析のサマリーラベル（空なら `記録なし`）。
  static String summaryLabel(List<IncomeEntry> entries) {
    final total = totalAmount(entries);
    if (total <= 0) return '収入の記録はまだない';
    final top = topSource(entries);
    return '合計 ¥$total・最多 ${top?.source ?? '-'}';
  }
}
