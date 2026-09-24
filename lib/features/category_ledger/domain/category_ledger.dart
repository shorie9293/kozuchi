import 'package:kozuchi/domain/services/expense_aggregation_service.dart';

/// カテゴリ名の検証エラー種別
enum CategoryNameError { empty, tooLong, duplicate, notFound, lastOne }

/// カテゴリ台帳（不変・表示順を保持）
///
/// 正規化済み・重複なし・表示順どおりのカテゴリ名リストを持つ。
/// 空の台帳は構成できない（未分類だけの台帳は不可）。
class CategoryLedger {
  /// 正規化済み・重複なし・表示順どおりのカテゴリ名
  final List<String> categories;

  /// 非const。空リストは [ArgumentError]。
  CategoryLedger(List<String> categories)
    : categories = List.unmodifiable(categories) {
    if (categories.isEmpty) {
      throw ArgumentError.value(
        categories,
        'categories',
        'カテゴリ台帳を空にすることはできません',
      );
    }
  }

  /// 既定カテゴリ（[ExpenseAggregationService.defaultCategories]）で作る
  factory CategoryLedger.defaults() {
    return CategoryLedger(ExpenseAggregationService.defaultCategories);
  }

  /// 既定と件数・順序・内容が完全一致するか
  bool get isDefault {
    final defaults = ExpenseAggregationService.defaultCategories;
    if (categories.length != defaults.length) return false;
    for (var i = 0; i < defaults.length; i++) {
      if (categories[i] != defaults[i]) return false;
    }
    return true;
  }

  /// [name] を含むか（正規化なしの文字列一致）
  bool contains(String name) => categories.contains(name);

  /// カテゴリ件数
  int get length => categories.length;

  /// JSON 用の文字列リストに変換
  List<String> toJson() => List.of(categories);

  /// 破損・不正（List以外/空/非文字列要素）は null
  static CategoryLedger? tryFromJson(Object? json) {
    if (json is! List) return null;
    if (json.isEmpty) return null;
    for (final item in json) {
      if (item is! String) return null;
    }
    try {
      return CategoryLedger(List<String>.from(json));
    } on ArgumentError {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is CategoryLedger &&
      other.runtimeType == runtimeType &&
      _listEquals(categories, other.categories);

  @override
  int get hashCode => Object.hashAll(categories);

  @override
  String toString() => 'CategoryLedger($categories)';

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
