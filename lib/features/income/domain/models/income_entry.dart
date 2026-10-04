/// 収入一件を表すモデル
///
/// Kozuchiアプリで記録される収入データの最小単位。
/// [ExpenseEntry] と対になる。収入源（source）ごとの集計に用いる。
class IncomeEntry {
  /// 一意識別子
  final String id;

  /// 収入金額（円）。正の値のみ。
  final int amount;

  /// 収入源（例: 給与, 副業, 贈与）
  final String source;

  /// 収入日時
  final DateTime date;

  /// 一言メモ（任意）
  final String? note;

  IncomeEntry({
    required this.id,
    required this.amount,
    required this.source,
    required this.date,
    this.note,
  }) {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'amount must be positive');
    }
    if (source.trim().isEmpty) {
      throw ArgumentError.value(source, 'source', 'source must not be empty');
    }
  }

  /// JSONから復元
  ///
  /// 破損データ（不正なamount / 空のsource）は
  /// [IncomeEntry] の検証で例外になるため、呼出側で読み飛ばすこと。
  factory IncomeEntry.fromJson(Map<String, dynamic> json) {
    return IncomeEntry(
      id: json['id'] as String,
      amount: json['amount'] as int,
      source: json['source'] as String,
      date: DateTime.parse(json['date'] as String),
      note: json['note'] as String?,
    );
  }

  /// JSONに変換
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'source': source,
      'date': date.toIso8601String(),
      'note': note,
    };
  }

  @override
  String toString() =>
      'IncomeEntry(id: $id, amount: $amount, source: $source, date: $date)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IncomeEntry && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
