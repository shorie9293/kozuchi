import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/tags/domain/models/tagged_transaction.dart';
import 'package:kozuchi/features/transaction_filter/domain/models/transaction_filter.dart';
import 'package:kozuchi/features/transaction_filter/domain/models/transaction_query_result.dart';

/// 取引検索の純粋ロジック（I/O 無し・例外を投げない）
abstract final class TransactionQueryService {
  /// キーワードの正規化。
  ///
  /// 全角英数字（A-Za-z0-9 相当）→ 半角、全角スペース（U+3000）→ 半角、
  /// 小文字化、前後 trim、連続空白を 1 つに圧縮する。
  static String normalizeKeyword(String raw) {
    final buffer = StringBuffer();
    for (final code in raw.runes) {
      if (code >= 0xFF01 && code <= 0xFF5A) {
        // 全角 ASCII（！〜ｚ）を半角へ（0xFF01 → 0x21）
        buffer.writeCharCode(code - 0xFEE0);
      } else if (code == 0x3000) {
        // 全角スペース → 半角スペース
        buffer.writeCharCode(0x20);
      } else {
        buffer.writeCharCode(code);
      }
    }
    return buffer
        .toString()
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  /// [tx] が [filter] の全条件を満たすか（AND）。
  ///
  /// [tagAssignments] は「取引キー → タグID列」のマップ。
  static bool matches(
    TransactionModel tx,
    TransactionFilter filter, {
    Map<String, List<String>> tagAssignments = const {},
  }) {
    // 種別
    switch (filter.type) {
      case TransactionFilterType.all:
        break;
      case TransactionFilterType.income:
        if (!tx.isIncome) return false;
      case TransactionFilterType.expense:
        if (tx.isIncome) return false;
    }

    // 日付範囲（日付のみで inclusive 比較）
    if (filter.startDate != null || filter.endDate != null) {
      final dateTime = DateTime.tryParse(tx.datetime);
      if (dateTime == null) return false;
      final date = DateTime(dateTime.year, dateTime.month, dateTime.day);
      final start = filter.startDate;
      if (start != null) {
        final startDate = DateTime(start.year, start.month, start.day);
        if (date.isBefore(startDate)) return false;
      }
      final end = filter.endDate;
      if (end != null) {
        final endDate = DateTime(end.year, end.month, end.day);
        if (date.isAfter(endDate)) return false;
      }
    }

    // キーワード（用途またはカテゴリの部分一致）
    if (filter.hasKeyword) {
      final needle = normalizeKeyword(filter.keyword);
      final purpose = normalizeKeyword(tx.purpose);
      final category = normalizeKeyword(tx.category);
      if (!purpose.contains(needle) && !category.contains(needle)) {
        return false;
      }
    }

    // カテゴリ集合
    if (filter.categories.isNotEmpty && !filter.categories.contains(tx.category)) {
      return false;
    }

    // タグ（いずれか 1 つでも紐付いていれば OK = OR）
    if (filter.tagIds.isNotEmpty) {
      final assigned = tagAssignments[TaggedTransaction.keyOfTransaction(tx)] ??
          const <String>[];
      var matched = false;
      for (final tagId in filter.tagIds) {
        if (assigned.contains(tagId)) {
          matched = true;
          break;
        }
      }
      if (!matched) return false;
    }

    return true;
  }

  /// [transactions] を [filter] で絞り込む。入力順序を保持し、非破壊。
  static List<TransactionModel> apply({
    required List<TransactionModel> transactions,
    required TransactionFilter filter,
    Map<String, List<String>> tagAssignments = const {},
  }) {
    final result = <TransactionModel>[];
    for (final tx in transactions) {
      if (matches(tx, filter, tagAssignments: tagAssignments)) {
        result.add(tx);
      }
    }
    return result;
  }

  /// 検索して集計する。
  static TransactionQueryResult query({
    required List<TransactionModel> transactions,
    required TransactionFilter filter,
    Map<String, List<String>> tagAssignments = const {},
  }) {
    final matched = apply(
      transactions: transactions,
      filter: filter,
      tagAssignments: tagAssignments,
    );
    var totalIncome = 0;
    var totalExpense = 0;
    for (final tx in matched) {
      if (tx.amount >= 0) {
        totalIncome += tx.amount;
      } else {
        totalExpense += -tx.amount;
      }
    }
    return TransactionQueryResult(
      transactions: List.unmodifiable(matched),
      count: matched.length,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      net: totalIncome - totalExpense,
    );
  }
}