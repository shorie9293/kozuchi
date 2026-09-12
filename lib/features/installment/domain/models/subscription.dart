/// サブスクリプション（定額課金サービス）
///
/// 毎月 [billingDay] 日に [amount] 円が課金される想定。金額はすべて正の円で保持する。
class Subscription {
  final String id;

  /// 名称（例: 「動画サブスク」）
  final String purpose;

  /// カテゴリ（例: 「趣味」）
  final String category;

  /// 月額（円、正の値）
  final int amount;

  /// 毎月の請求日（1..31、月末調整あり）
  final int billingDay;

  /// 契約開始日
  final DateTime startDate;

  /// 有効フラグ（false の間は月額集計・リマインド対象外）
  final bool isActive;

  const Subscription({
    required this.id,
    required this.purpose,
    required this.category,
    required this.amount,
    this.billingDay = 1,
    required this.startDate,
    this.isActive = true,
  });

  /// 年額（月額 × 12）
  int get yearlyAmount => amount * 12;

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'] as String? ?? '',
      purpose: json['purpose'] as String? ?? '',
      category: json['category'] as String? ?? '',
      amount: json['amount'] as int? ?? 0,
      billingDay: json['billingDay'] as int? ?? 1,
      startDate:
          DateTime.tryParse(json['startDate'] as String? ?? '') ?? DateTime.now(),
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'purpose': purpose,
      'category': category,
      'amount': amount,
      'billingDay': billingDay,
      'startDate': startDate.toIso8601String(),
      'isActive': isActive,
    };
  }

  /// id が同一なら等価とみなす
  @override
  bool operator ==(Object other) => other is Subscription && other.id == id;

  @override
  int get hashCode => id.hashCode;

  Subscription copyWith({
    String? purpose,
    String? category,
    int? amount,
    int? billingDay,
    DateTime? startDate,
    bool? isActive,
  }) {
    return Subscription(
      id: id,
      purpose: purpose ?? this.purpose,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      billingDay: billingDay ?? this.billingDay,
      startDate: startDate ?? this.startDate,
      isActive: isActive ?? this.isActive,
    );
  }
}
