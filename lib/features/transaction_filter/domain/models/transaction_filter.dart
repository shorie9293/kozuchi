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
/// [type] で種別、[startDate]/[endDate] で日付範囲を指定する。
/// イミュータブル（不変）で、== 比較による等価判定をサポートする。
class TransactionFilter {
  /// 取引種別（デフォルト: 全件）
  final TransactionFilterType type;

  /// 開始日（null の場合は制限なし）
  final DateTime? startDate;

  /// 終了日（null の場合は制限なし）
  final DateTime? endDate;

  const TransactionFilter({
    this.type = TransactionFilterType.all,
    this.startDate,
    this.endDate,
  });

  /// 一部のフィールドのみ変更した新しいフィルタを返す
  TransactionFilter copyWith({
    TransactionFilterType? type,
    DateTime? startDate,
    DateTime? endDate,
    bool clearStartDate = false,
    bool clearEndDate = false,
  }) {
    return TransactionFilter(
      type: type ?? this.type,
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
    );
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
    };
  }

  /// JSON から復元
  factory TransactionFilter.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String? value) {
      if (value == null) return null;
      return DateTime.tryParse(value);
    }

    return TransactionFilter(
      type: TransactionFilterType.values.firstWhere(
        (t) => t.name == (json['type'] as String? ?? 'all'),
        orElse: () => TransactionFilterType.all,
      ),
      startDate: parseDate(json['startDate'] as String?),
      endDate: parseDate(json['endDate'] as String?),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TransactionFilter &&
      type == other.type &&
      startDate == other.startDate &&
      endDate == other.endDate;

  @override
  int get hashCode => Object.hash(type, startDate, endDate);
}
