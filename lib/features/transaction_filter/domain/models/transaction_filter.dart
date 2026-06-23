/// 取引種別フィルタ
enum TransactionFilterType {
  /// 全件
  all('全件'),

  /// 収入のみ
  income('収入'),

  /// 支出のみ
  expense('支出');

  /// 日本語表示ラベル
  final String label;

  const TransactionFilterType(this.label);
}

/// 取引履歴画面のフィルタ状態を保持する不変な値オブジェクト。
///
/// 種別（全件/収入/支出）と日付範囲（開始日〜終了日）を保持し、
/// 画面やデータ取得クエリに渡すための統一的なフィルタ表現を提供する。
class TransactionFilter {
  /// 取引種別（デフォルト: 全件）
  final TransactionFilterType type;

  /// 開始日（nullの場合は制限なし）
  final DateTime? startDate;

  /// 終了日（nullの場合は制限なし）
  final DateTime? endDate;

  const TransactionFilter({
    this.type = TransactionFilterType.all,
    this.startDate,
    this.endDate,
  });

  /// コピーを作成し、指定されたフィールドのみ変更する
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

  /// JSONに変換（日付は YYYY-MM-DD 形式の文字列）
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      if (startDate != null) 'startDate': _dateToString(startDate!),
      if (endDate != null) 'endDate': _dateToString(endDate!),
    };
  }

  /// JSONから復元
  factory TransactionFilter.fromJson(Map<String, dynamic> json) {
    return TransactionFilter(
      type: _parseType(json['type'] as String? ?? 'all'),
      startDate: json['startDate'] != null
          ? DateTime.tryParse(json['startDate'] as String)
          : null,
      endDate: json['endDate'] != null
          ? DateTime.tryParse(json['endDate'] as String)
          : null,
    );
  }

  static TransactionFilterType _parseType(String name) {
    return TransactionFilterType.values.firstWhere(
      (t) => t.name == name,
      orElse: () => TransactionFilterType.all,
    );
  }

  static String _dateToString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TransactionFilter &&
        other.type == type &&
        other.startDate == startDate &&
        other.endDate == endDate;
  }

  @override
  int get hashCode => Object.hash(type, startDate, endDate);
}
