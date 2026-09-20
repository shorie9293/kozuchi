/// 取引種別フィルタ
enum TransactionFilterType {
  /// 全件（収入＋支出）
  all,

  /// 収入のみ
  income,

  /// 支出のみ
  expense;

  /// 日本語ラベル
  String get label {
    switch (this) {
      case TransactionFilterType.all:
        return '全件';
      case TransactionFilterType.income:
        return '収入';
      case TransactionFilterType.expense:
        return '支出';
    }
  }
}

/// 取引一覧のフィルタ条件
///
/// [type] で種別、[startDate]/[endDate] で日付範囲、[keyword] で
/// 用途・カテゴリの部分一致、[categories]/[tagIds] で集合絞り込みを指定する。
/// イミュータブル（不変）で、== 比較による等価判定をサポートする。
class TransactionFilter {
  /// 取引種別（デフォルト: 全件）
  final TransactionFilterType type;

  /// 開始日（null の場合は制限なし）
  final DateTime? startDate;

  /// 終了日（null の場合は制限なし）
  final DateTime? endDate;

  /// 検索キーワード（用途・カテゴリの部分一致、'' の場合は制限なし）
  final String keyword;

  /// カテゴリ絞り込み（空集合の場合は制限なし）
  final Set<String> categories;

  /// タグID絞り込み（空集合の場合は制限なし）
  final Set<String> tagIds;

  const TransactionFilter({
    this.type = TransactionFilterType.all,
    this.startDate,
    this.endDate,
    this.keyword = '',
    this.categories = const {},
    this.tagIds = const {},
  });

  /// 一部のフィールドのみ変更した新しいフィルタを返す
  TransactionFilter copyWith({
    TransactionFilterType? type,
    DateTime? startDate,
    DateTime? endDate,
    String? keyword,
    Set<String>? categories,
    Set<String>? tagIds,
    bool clearStartDate = false,
    bool clearEndDate = false,
    bool clearKeyword = false,
  }) {
    return TransactionFilter(
      type: type ?? this.type,
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      keyword: clearKeyword ? '' : (keyword ?? this.keyword),
      categories: categories == null ? this.categories : Set<String>.of(categories),
      tagIds: tagIds == null ? this.tagIds : Set<String>.of(tagIds),
    );
  }

  /// キーワードが実質設定されているか（空白のみは未設定扱い）
  bool get hasKeyword => keyword.trim().isNotEmpty;

  /// 何も絞り込んでいないデフォルト状態か
  bool get isDefault =>
      type == TransactionFilterType.all &&
      startDate == null &&
      endDate == null &&
      !hasKeyword &&
      categories.isEmpty &&
      tagIds.isEmpty;

  /// 有効になっているフィルタ条件の数
  ///
  /// type != all を 1、startDate を 1、endDate を 1、hasKeyword を 1、
  /// categories 非空を 1、tagIds 非空を 1 とした合計。
  int get activeFilterCount {
    var count = 0;
    if (type != TransactionFilterType.all) count++;
    if (startDate != null) count++;
    if (endDate != null) count++;
    if (hasKeyword) count++;
    if (categories.isNotEmpty) count++;
    if (tagIds.isNotEmpty) count++;
    return count;
  }

  /// JSON にシリアライズ
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      if (startDate != null)
        'startDate':
            '${startDate!.year}-${startDate!.month.toString().padLeft(2, '0')}-${startDate!.day.toString().padLeft(2, '0')}',
      if (endDate != null)
        'endDate':
            '${endDate!.year}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}',
      if (hasKeyword) 'keyword': keyword,
      if (categories.isNotEmpty) 'categories': categories.toList(),
      if (tagIds.isNotEmpty) 'tagIds': tagIds.toList(),
    };
  }

  /// JSON から復元
  factory TransactionFilter.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String? value) {
      if (value == null) return null;
      return DateTime.tryParse(value);
    }

    Set<String> parseStringSet(dynamic raw) {
      final result = <String>{};
      if (raw is List) {
        for (final value in raw) {
          if (value is String && value.isNotEmpty) result.add(value);
        }
      }
      return result;
    }

    return TransactionFilter(
      type: TransactionFilterType.values.firstWhere(
        (t) => t.name == (json['type'] as String? ?? 'all'),
        orElse: () => TransactionFilterType.all,
      ),
      startDate: parseDate(json['startDate'] as String?),
      endDate: parseDate(json['endDate'] as String?),
      keyword: json['keyword'] is String ? json['keyword'] as String : '',
      categories: parseStringSet(json['categories']),
      tagIds: parseStringSet(json['tagIds']),
    );
  }

  /// 集合を順序非依存で比較するヘルパ
  static bool _setEquals(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    for (final value in a) {
      if (!b.contains(value)) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is TransactionFilter &&
      type == other.type &&
      startDate == other.startDate &&
      endDate == other.endDate &&
      keyword == other.keyword &&
      _setEquals(categories, other.categories) &&
      _setEquals(tagIds, other.tagIds);

  @override
  int get hashCode => Object.hash(
        type,
        startDate,
        endDate,
        keyword,
        Object.hashAllUnordered(categories),
        Object.hashAllUnordered(tagIds),
      );
}