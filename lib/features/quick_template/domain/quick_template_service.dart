import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/features/quick_template/domain/models/expense_template.dart';

/// 支出入力欄へ流し込む軽量値
///
/// テンプレートから入力欄（金額・用途・カテゴリ）へ展開するための
/// 値クラス。永続化は担わない。
class ExpenseTemplateDraft {
  /// 支出金額（円）
  final int amount;

  /// 用途
  final String purpose;

  /// カテゴリ名
  final String category;

  const ExpenseTemplateDraft({
    required this.amount,
    required this.purpose,
    required this.category,
  });

  @override
  bool operator ==(Object other) =>
      other is ExpenseTemplateDraft &&
      amount == other.amount &&
      purpose == other.purpose &&
      category == other.category;

  @override
  int get hashCode => Object.hash(amount, purpose, category);

  @override
  String toString() => 'ExpenseTemplateDraft($amount, $purpose, $category)';
}

/// クイックテンプレートの純粋ロジック集
///
/// I/O は一切行わず、リスト操作と変換のみを提供する。
/// すべて静的メソッドとして利用する。
abstract final class QuickTemplateService {
  /// 使用頻度順に並べ替えた新しいリストを返す。
  ///
  /// 順序: useCount 降順 → lastUsedAt 降順（null は末尾）→
  /// createdAt 昇順 → id 昇順。
  static List<ExpenseTemplate> sortByUsage(
    List<ExpenseTemplate> templates,
  ) {
    final sorted = [...templates];
    sorted.sort((a, b) {
      if (a.useCount != b.useCount) return b.useCount - a.useCount;
      final aLast = a.lastUsedAt;
      final bLast = b.lastUsedAt;
      if (aLast == null && bLast != null) return 1;
      if (aLast != null && bLast == null) return -1;
      if (aLast != null && bLast != null) {
        final cmp = bLast.compareTo(aLast);
        if (cmp != 0) return cmp;
      }
      final created = a.createdAt.compareTo(b.createdAt);
      if (created != 0) return created;
      return a.id.compareTo(b.id);
    });
    return sorted;
  }

  /// [template] を既存リストに反映する（同一 id は置換、無ければ追加）。
  ///
  /// 不正なテンプレート（amount<=0・空 purpose・空 category）は
  /// [ArgumentError]。
  static List<ExpenseTemplate> upsert(
    List<ExpenseTemplate> templates,
    ExpenseTemplate template,
  ) {
    _validate(template);
    final next = [...templates.where((t) => t.id != template.id), template];
    return next;
  }

  /// 指定 id のテンプレートを取り除いた新しいリストを返す。
  static List<ExpenseTemplate> remove(
    List<ExpenseTemplate> templates,
    String id,
  ) {
    return [...templates.where((t) => t.id != id)];
  }

  /// [template] を使用した記録として、使用回数 +1・最終使用日時 [now]
  /// の新しいテンプレートを返す。
  static ExpenseTemplate applyTemplate(
    ExpenseTemplate template,
    DateTime now,
  ) {
    return template.copyWith(useCount: template.useCount + 1, lastUsedAt: now);
  }

  /// 使用頻度順の先頭 [limit] 件を返す。
  ///
  /// [limit] <= 0 は [ArgumentError]。
  static List<ExpenseTemplate> frequentTemplates(
    List<ExpenseTemplate> templates, {
    int limit = 5,
  }) {
    if (limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'limit は正である必要がある');
    }
    return sortByUsage(templates).take(limit).toList();
  }

  /// [template] を入力欄用の軽量値に変換する。
  static ExpenseTemplateDraft draftOf(ExpenseTemplate template) {
    return ExpenseTemplateDraft(
      amount: template.amount,
      purpose: template.purpose,
      category: template.category,
    );
  }

  /// 過去の支出履歴からテンプレート候補を生成する。
  ///
  /// 用途 + カテゴリ単位で頻度集計し、出現回数降順 → 金額中央値降順
  /// （偶数個は下位側）→ 用途昇順 で並べ替えて返す。
  /// 金額の代表値はその組での最頻額、同数なら最新の額とする。
  /// [limit] <= 0 は [ArgumentError]。
  static List<ExpenseTemplate> suggestFromEntries(
    List<ExpenseEntry> entries, {
    int limit = 5,
  }) {
    if (limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'limit は正である必要がある');
    }

    // 用途+カテゴリ単位でグループ化
    final groups = <String, List<ExpenseEntry>>{};
    for (final entry in entries) {
      final key = '${entry.purposeKey}|${entry.category}';
      groups.putIfAbsent(key, () => []).add(entry);
    }

    final candidates = <(ExpenseTemplate, int)>[]; // (候補, 中央値)
    groups.forEach((key, group) {
      final separator = key.indexOf('|');
      final purpose = key.substring(0, separator);
      final category = key.substring(separator + 1);

      // 金額の代表値: 最頻額、同数なら最新の額
      final amounts = <int, int>{};
      for (final e in group) {
        amounts[e.amount] = (amounts[e.amount] ?? 0) + 1;
      }
      final maxCount =
          amounts.values.reduce((a, b) => a > b ? a : b);
      final tied = amounts.entries
          .where((e) => e.value == maxCount)
          .map((e) => e.key)
          .toList();
      tied.sort((a, b) {
        final aLatest = group
            .where((e) => e.amount == a)
            .map((e) => e.date)
            .reduce((x, y) => x.isAfter(y) ? x : y);
        final bLatest = group
            .where((e) => e.amount == b)
            .map((e) => e.date)
            .reduce((x, y) => x.isAfter(y) ? x : y);
        return bLatest.compareTo(aLatest);
      });
      final amount = tied.first;

      // 中央値（偶数個は下位側）— 並べ替えの比較で使用
      final sortedAmounts = group.map((e) => e.amount).toList()..sort();
      final median = sortedAmounts[(sortedAmounts.length - 1) ~/ 2];

      // 最新の支出日時を作成日時代わりに使う
      final latest = group.map((e) => e.date).reduce((a, b) => a.isAfter(b) ? a : b);

      candidates.add((
        ExpenseTemplate(
          id: 'suggest_${purpose}_$category',
          amount: amount,
          purpose: purpose,
          category: category,
          useCount: group.length,
          lastUsedAt: latest,
          createdAt: latest,
        ),
        median,
      ));
    });

    candidates.sort((a, b) {
      if (a.$1.useCount != b.$1.useCount) {
        return b.$1.useCount - a.$1.useCount;
      }
      final cmp = b.$2.compareTo(a.$2);
      if (cmp != 0) return cmp;
      return a.$1.purpose.compareTo(b.$1.purpose);
    });

    return candidates.map((c) => c.$1).take(limit).toList();
  }

  /// テンプレートの基本検証。
  static void _validate(ExpenseTemplate template) {
    if (template.amount <= 0) {
      throw ArgumentError.value(template.amount, 'amount', '金額は正である必要がある');
    }
    if (template.purpose.trim().isEmpty) {
      throw ArgumentError.value(template.purpose, 'purpose', '用途を空にはできません');
    }
    if (template.category.trim().isEmpty) {
      throw ArgumentError.value(template.category, 'category', 'カテゴリを空にはできません');
    }
  }
}

extension on ExpenseEntry {
  /// 用途（このアプリでは note を用途として扱う）
  String get purposeKey => note ?? '';
}
