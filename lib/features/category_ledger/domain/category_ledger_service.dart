import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/domain/services/expense_aggregation_service.dart';
import 'package:kozuchi/features/category_ledger/domain/category_ledger.dart';
import 'package:kozuchi/features/category_ledger/domain/category_usage.dart';

/// カテゴリ台帳の純粋ロジック集
///
/// I/O は一切行わない。入力不正時のみ [ArgumentError] を投げる。
class CategoryLedgerService {
  const CategoryLedgerService();

  /// カテゴリ名の最大長
  static const int maxNameLength = 12;

  /// 既定カテゴリ名（[ExpenseAggregationService.defaultCategories] をそのまま）
  static List<String> get defaultNames =>
      List.unmodifiable(ExpenseAggregationService.defaultCategories);

  /// 正規化: 全角スペース→半角 / 連続空白→単一 / 前後trim
  static String normalize(String raw) {
    return raw.replaceAll('\u3000', ' ').trim().replaceAll(
      RegExp(' +'),
      ' ',
    );
  }

  /// [raw] を新規追加できるか検証する。問題なければ null。
  CategoryNameError? validateNew(CategoryLedger ledger, String raw) {
    final name = normalize(raw);
    if (name.isEmpty) return CategoryNameError.empty;
    if (name.length > maxNameLength) return CategoryNameError.tooLong;
    final names = ledger.categories.map(normalize).toSet();
    if (names.contains(name)) return CategoryNameError.duplicate;
    return null;
  }

  /// カテゴリを追加する。不正入力は [ArgumentError]。
  CategoryLedger add(CategoryLedger ledger, String raw) {
    final error = validateNew(ledger, raw);
    if (error != null) {
      throw ArgumentError.value(raw, 'raw', 'カテゴリ追加不可: $error');
    }
    return CategoryLedger([...ledger.categories, normalize(raw)]);
  }

  /// カテゴリ名を変更する。
  ///
  /// [from] が台帳に無ければ [ArgumentError]。
  /// [raw] が [from]（正規化後）と同一なら同一内容の台帳を返す（no-op）。
  CategoryLedger rename(CategoryLedger ledger, String from, String raw) {
    final normalizedFrom = normalize(from);
    if (!ledger.categories.any((c) => normalize(c) == normalizedFrom)) {
      throw ArgumentError.value(from, 'from', 'カテゴリが台帳に存在しません');
    }
    final newName = normalize(raw);
    if (newName.isEmpty) {
      throw ArgumentError.value(raw, 'raw', 'カテゴリ名を空にはできません');
    }
    if (newName.length > maxNameLength) {
      throw ArgumentError.value(raw, 'raw', 'カテゴリ名が長すぎます');
    }
    if (newName == normalizedFrom) {
      return ledger;
    }
    // 他カテゴリとの重複は不可
    final clash = ledger.categories.any(
      (c) => normalize(c) == newName && normalize(c) != normalizedFrom,
    );
    if (clash) {
      throw ArgumentError.value(raw, 'raw', 'カテゴリ名が重複しています');
    }
    final next = ledger.categories
        .map((c) => normalize(c) == normalizedFrom ? newName : c)
        .toList();
    return CategoryLedger(next);
  }

  /// カテゴリを取り除く。
  ///
  /// 台帳に無ければ [ArgumentError]、結果が空になる（最後の1件）なら
  /// [ArgumentError]。
  CategoryLedger remove(CategoryLedger ledger, String name) {
    final normalized = normalize(name);
    if (!ledger.categories.any((c) => normalize(c) == normalized)) {
      throw ArgumentError.value(name, 'name', 'カテゴリが台帳に存在しません');
    }
    if (ledger.length <= 1) {
      throw ArgumentError.value(name, 'name', '最後のカテゴリは削除できません');
    }
    return CategoryLedger(
      ledger.categories
          .where((c) => normalize(c) != normalized)
          .toList(),
    );
  }

  /// 既定カテゴリの台帳を返す
  CategoryLedger reset() => CategoryLedger.defaults();

  /// カテゴリ別の使用実績を返す。
  ///
  /// 並び: 台帳順（実績0のカテゴリも含める）→ 孤立カテゴリ
  /// （amount 降順 → 名前昇順）。
  /// amount<=0 のエントリと category が空白のみのエントリは無視。
  List<CategoryUsage> usage(
    CategoryLedger ledger,
    List<ExpenseEntry> entries,
  ) {
    final byName = <String, (int, int)>{};
    for (final entry in entries) {
      if (entry.amount <= 0) continue;
      final name = normalize(entry.category);
      if (name.isEmpty) continue;
      final (count, amount) = byName[name] ?? (0, 0);
      byName[name] = (count + 1, amount + entry.amount);
    }

    final result = <CategoryUsage>[];
    final seen = <String>{};
    for (final category in ledger.categories) {
      final record = byName[category];
      result.add(
        CategoryUsage(
          category: category,
          count: record?.$1 ?? 0,
          amount: record?.$2 ?? 0,
          inLedger: true,
        ),
      );
      seen.add(category);
    }

    final orphans = byName.keys.where((n) => !seen.contains(n)).toList()
      ..sort((a, b) {
        final amountCmp = byName[b]!.$2.compareTo(byName[a]!.$2);
        if (amountCmp != 0) return amountCmp;
        return a.compareTo(b);
      });
    for (final name in orphans) {
      final (count, amount) = byName[name]!;
      result.add(
        CategoryUsage(
          category: name,
          count: count,
          amount: amount,
          inLedger: false,
        ),
      );
    }
    return result;
  }

  /// [name] が amount>0 のエントリに現れるか
  bool isInUse(String name, List<ExpenseEntry> entries) {
    final normalized = normalize(name);
    return entries.any(
      (e) => e.amount > 0 && normalize(e.category) == normalized,
    );
  }

  /// 外部由来のカテゴリ名（自動分類器など）を台帳の正準名へ寄せる。
  ///
  /// 解決順: 完全一致 → 末尾「費」の有無を吸収した一致。
  /// 台帳に該当が無ければ null（勝手にカテゴリを増やさない）。
  ///
  /// 分類辞書は「交通」を返すが台帳は「交通費」というように
  /// 語尾が食い違うため、放置すると取引が孤立カテゴリに落ちる。
  String? resolveName(CategoryLedger ledger, String raw) {
    final name = normalize(raw);
    if (name.isEmpty) return null;

    for (final category in ledger.categories) {
      if (normalize(category) == name) return category;
    }

    if (name.endsWith('費')) {
      final withoutSuffix = name.substring(0, name.length - 1);
      if (withoutSuffix.isNotEmpty) {
        for (final category in ledger.categories) {
          if (normalize(category) == withoutSuffix) return category;
        }
      }
    } else {
      for (final category in ledger.categories) {
        if (normalize(category) == '$name費') return category;
      }
    }
    return null;
  }

  /// カテゴリの絵文字。既知以外は 📦（例外は投げない）。
  String emojiFor(String category) {
    return _emojiMap[category] ?? '📦';
  }

  static const Map<String, String> _emojiMap = {
    '食費': '🍙',
    '娯楽': '🎮',
    '交通費': '🚃',
    '交通': '🚃',
    '光熱費': '💡',
    '交際費': '🎁',
    '日用品': '🧻',
    '住居費': '🏠',
    '医療費': '🏥',
    '教育費': '📚',
    '衣服費': '👕',
    '通信費': '📱',
    'その他': '📦',
  };
}
