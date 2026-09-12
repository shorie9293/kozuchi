/// 分割払いプラン（残債の管理）
///
/// 総額 [totalAmount] を [installmentCount] 回で支払う。金額はすべて正の円で保持し、
/// 支払いの進捗は [paidCount]（返済済み回数）で表す。
class InstallmentPlan {
  final String id;

  /// 名称（例: 「新しい冷蔵庫」）
  final String purpose;

  /// カテゴリ（例: 「家電」）
  final String category;

  /// 総額（円、正の値）
  final int totalAmount;

  /// 分割回数（1以上）
  final int installmentCount;

  /// 初回支払日
  final DateTime startDate;

  /// 返済済み回数（0以上）
  final int paidCount;

  /// 有効フラグ
  final bool isActive;

  const InstallmentPlan({
    required this.id,
    required this.purpose,
    required this.category,
    required this.totalAmount,
    required this.installmentCount,
    required this.startDate,
    this.paidCount = 0,
    this.isActive = true,
  });

  /// 残りの返済回数（0未満にはならない）
  int get remainingCount {
    final remaining = installmentCount - paidCount;
    return remaining < 0 ? 0 : remaining;
  }

  /// 完済済みか
  bool get isCompleted => paidCount >= installmentCount;

  /// 返済の進捗率（0.0〜1.0、回数ベース）
  double get progress {
    if (installmentCount <= 0) return 1.0;
    return (paidCount / installmentCount).clamp(0.0, 1.0).toDouble();
  }

  factory InstallmentPlan.fromJson(Map<String, dynamic> json) {
    return InstallmentPlan(
      id: json['id'] as String? ?? '',
      purpose: json['purpose'] as String? ?? '',
      category: json['category'] as String? ?? '',
      totalAmount: json['totalAmount'] as int? ?? 0,
      installmentCount: json['installmentCount'] as int? ?? 1,
      startDate:
          DateTime.tryParse(json['startDate'] as String? ?? '') ?? DateTime.now(),
      paidCount: json['paidCount'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'purpose': purpose,
      'category': category,
      'totalAmount': totalAmount,
      'installmentCount': installmentCount,
      'startDate': startDate.toIso8601String(),
      'paidCount': paidCount,
      'isActive': isActive,
    };
  }

  /// id が同一なら等価とみなす
  @override
  bool operator ==(Object other) =>
      other is InstallmentPlan && other.id == id;

  @override
  int get hashCode => id.hashCode;

  InstallmentPlan copyWith({
    String? purpose,
    String? category,
    int? totalAmount,
    int? installmentCount,
    DateTime? startDate,
    int? paidCount,
    bool? isActive,
  }) {
    return InstallmentPlan(
      id: id,
      purpose: purpose ?? this.purpose,
      category: category ?? this.category,
      totalAmount: totalAmount ?? this.totalAmount,
      installmentCount: installmentCount ?? this.installmentCount,
      startDate: startDate ?? this.startDate,
      paidCount: paidCount ?? this.paidCount,
      isActive: isActive ?? this.isActive,
    );
  }
}
