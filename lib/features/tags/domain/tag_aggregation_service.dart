import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/tags/domain/models/expense_tag.dart';
import 'package:kozuchi/features/tags/domain/models/tagged_transaction.dart';

/// タグ1件分の集計結果
class TagTotal {
  /// タグID
  final String tagId;

  /// タグ名（タグ定義が無い場合は空文字）
  final String name;

  /// 紐付く取引件数
  final int count;

  /// 支出合計（正の値）
  final int expenseTotal;

  /// 収入合計（正の値）
  final int incomeTotal;

  const TagTotal({
    required this.tagId,
    this.name = '',
    this.count = 0,
    this.expenseTotal = 0,
    this.incomeTotal = 0,
  });

  /// 収支の差（収入 - 支出）
  int get netTotal => incomeTotal - expenseTotal;

  /// 取引が1件も無いか
  bool get isEmpty => count == 0;

  @override
  bool operator ==(Object other) =>
      other is TagTotal &&
      tagId == other.tagId &&
      name == other.name &&
      count == other.count &&
      expenseTotal == other.expenseTotal &&
      incomeTotal == other.incomeTotal;

  @override
  int get hashCode =>
      Object.hash(tagId, name, count, expenseTotal, incomeTotal);

  @override
  String toString() => 'TagTotal($tagId, $name, $count)';
}

/// タグ別集計の結果
class TagAggregationResult {
  /// タグ別合計（支出合計の降順 → タグID昇順）
  final List<TagTotal> totals;

  /// タグが紐付いていない取引の件数
  final int untaggedCount;

  /// タグが紐付いていない支出の合計
  final int untaggedExpenseTotal;

  /// タグが紐付いていない収入の合計
  final int untaggedIncomeTotal;

  const TagAggregationResult({
    this.totals = const [],
    this.untaggedCount = 0,
    this.untaggedExpenseTotal = 0,
    this.untaggedIncomeTotal = 0,
  });

  /// 集計対象が1件も無いか
  bool get isEmpty => totals.every((t) => t.isEmpty) && untaggedCount == 0;

  /// 指定タグの合計（無ければ null）
  TagTotal? totalForTag(String tagId) {
    for (final total in totals) {
      if (total.tagId == tagId) return total;
    }
    return null;
  }

  @override
  String toString() =>
      'TagAggregationResult(${totals.length} tags, untagged=$untaggedCount)';
}

/// タグ別集計・絞り込みの純粋ロジック
///
/// IO を持たず、取引一覧と紐付けマップ（transactionKey → タグID列）から
/// 集計結果を算出する。日時が不正な取引や紐付けの無いキーは無視する。
class TagAggregationService {
  const TagAggregationService();

  /// タグ別に集計する。
  ///
  /// [tags] を渡した場合、利用実績ゼロのタグも 0 件の [TagTotal] として
  /// 結果に含める（集計画面でタグ定義を漏れなく表示するため）。
  /// [assignments] に現れる未知のタグIDも合計に含める。
  TagAggregationResult summarize({
    required List<TransactionModel> transactions,
    Map<String, List<String>> assignments = const {},
    List<ExpenseTag> tags = const [],
  }) {
    final names = <String, String>{
      for (final tag in tags) tag.id: tag.name,
    };

    final counts = <String, int>{};
    final expenses = <String, int>{};
    final incomes = <String, int>{};

    // 実績ゼロのタグも表示できるよう初期化
    for (final tag in tags) {
      counts[tag.id] = 0;
      expenses[tag.id] = 0;
      incomes[tag.id] = 0;
    }

    var untaggedCount = 0;
    var untaggedExpense = 0;
    var untaggedIncome = 0;

    for (final transaction in transactions) {
      final key = TaggedTransaction.keyOfTransaction(transaction);
      final tagIds = _distinctTags(assignments[key] ?? const []);

      if (tagIds.isEmpty) {
        untaggedCount++;
        if (transaction.isIncome) {
          untaggedIncome += transaction.amount;
        } else {
          untaggedExpense += transaction.absAmount;
        }
        continue;
      }

      for (final tagId in tagIds) {
        counts[tagId] = (counts[tagId] ?? 0) + 1;
        expenses.putIfAbsent(tagId, () => 0);
        incomes.putIfAbsent(tagId, () => 0);
        if (transaction.isIncome) {
          incomes[tagId] = incomes[tagId]! + transaction.amount;
        } else {
          expenses[tagId] = expenses[tagId]! + transaction.absAmount;
        }
        names.putIfAbsent(tagId, () => '');
      }
    }

    final totals = counts.keys
        .map((tagId) => TagTotal(
              tagId: tagId,
              name: names[tagId] ?? '',
              count: counts[tagId] ?? 0,
              expenseTotal: expenses[tagId] ?? 0,
              incomeTotal: incomes[tagId] ?? 0,
            ))
        .toList();

    totals.sort((a, b) {
      final byExpense = b.expenseTotal.compareTo(a.expenseTotal);
      if (byExpense != 0) return byExpense;
      return a.tagId.compareTo(b.tagId);
    });

    return TagAggregationResult(
      totals: List.unmodifiable(totals),
      untaggedCount: untaggedCount,
      untaggedExpenseTotal: untaggedExpense,
      untaggedIncomeTotal: untaggedIncome,
    );
  }

  /// 指定タグの取引のみに絞り込む。
  ///
  /// [tagId] が null または空文字の場合は「タグなし」の取引を返す。
  /// 元の並び順は保持する。
  List<TransactionModel> filterByTag({
    required List<TransactionModel> transactions,
    Map<String, List<String>> assignments = const {},
    String? tagId,
  }) {
    final targetsUntagged = tagId == null || tagId.isEmpty;
    final result = <TransactionModel>[];
    for (final transaction in transactions) {
      final key = TaggedTransaction.keyOfTransaction(transaction);
      final tagIds = _distinctTags(assignments[key] ?? const []);
      final matches = targetsUntagged ? tagIds.isEmpty : tagIds.contains(tagId);
      if (matches) result.add(transaction);
    }
    return List.unmodifiable(result);
  }

  static List<String> _distinctTags(List<String> raw) {
    final seen = <String>{};
    final result = <String>[];
    for (final value in raw) {
      if (value.isEmpty) continue;
      if (seen.add(value)) result.add(value);
    }
    return result;
  }
}
