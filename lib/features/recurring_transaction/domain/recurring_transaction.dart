/// 定期取引の頻度
enum RecurringFrequency {
  daily('毎日'),
  weekly('毎週'),
  monthly('毎月');

  final String label;
  const RecurringFrequency(this.label);

  static RecurringFrequency fromName(String name) {
    return values.firstWhere(
      (e) => e.name == name,
      orElse: () => RecurringFrequency.monthly,
    );
  }
}

/// 定期取引定義
///
/// 毎日/毎週/毎月のパターンで自動生成する取引の定義。
/// [amount] の符号で収入（正）・支出（負）を区別する。
class RecurringTransaction {
  final String id;
  final String purpose;
  final String category;

  /// 金額（円）。正 = 収入、負 = 支出。
  final int amount;

  final RecurringFrequency frequency;

  /// 週次の発生曜日（DateTime.monday=1 .. DateTime.sunday=7）
  final int dayOfWeek;

  /// 月次の発生日（1..31、月末調整あり）
  final int dayOfMonth;

  /// 開始日
  final DateTime startDate;

  /// 有効フラグ（false の間は自動記録されない）
  final bool isActive;

  const RecurringTransaction({
    required this.id,
    required this.purpose,
    required this.category,
    required this.amount,
    required this.frequency,
    this.dayOfWeek = DateTime.monday,
    this.dayOfMonth = 1,
    required this.startDate,
    this.isActive = true,
  });

  factory RecurringTransaction.fromJson(Map<String, dynamic> json) {
    return RecurringTransaction(
      id: json['id'] as String? ?? '',
      purpose: json['purpose'] as String? ?? '',
      category: json['category'] as String? ?? '',
      amount: json['amount'] as int? ?? 0,
      frequency: RecurringFrequency.fromName(json['frequency'] as String? ?? ''),
      dayOfWeek: json['dayOfWeek'] as int? ?? DateTime.monday,
      dayOfMonth: json['dayOfMonth'] as int? ?? 1,
      startDate: DateTime.tryParse(json['startDate'] as String? ?? '') ??
          DateTime.now(),
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'purpose': purpose,
      'category': category,
      'amount': amount,
      'frequency': frequency.name,
      'dayOfWeek': dayOfWeek,
      'dayOfMonth': dayOfMonth,
      'startDate': startDate.toIso8601String(),
      'isActive': isActive,
    };
  }

  /// id が同一なら等価とみなす
  @override
  bool operator ==(Object other) =>
      other is RecurringTransaction && other.id == id;

  @override
  int get hashCode => id.hashCode;

  RecurringTransaction copyWith({
    String? purpose,
    String? category,
    int? amount,
    RecurringFrequency? frequency,
    int? dayOfWeek,
    int? dayOfMonth,
    DateTime? startDate,
    bool? isActive,
  }) {
    return RecurringTransaction(
      id: id,
      purpose: purpose ?? this.purpose,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      frequency: frequency ?? this.frequency,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      startDate: startDate ?? this.startDate,
      isActive: isActive ?? this.isActive,
    );
  }
}
