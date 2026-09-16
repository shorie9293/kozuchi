/// 支出テンプレート（よく使う支出のワンタップ登録用）
///
/// 過去に入力した支出の金額・用途・カテゴリの組み合わせを
/// テンプレートとして保存し、ワンタップで入力欄へ流し込めるようにする。
///
/// イミュータブル（不変）で `==` 比較による等価判定をサポートする。
/// 破損データは [fromJson] が `null` を返すことで読み飛ばせる。
class ExpenseTemplate {
  /// 一意識別子
  final String id;

  /// 支出金額（円・正の整数）
  final int amount;

  /// 用途（テンプレート名としても表示する）
  final String purpose;

  /// カテゴリ名（例: 食費, 娯楽, 交通）
  final String category;

  /// 使用回数（0 以上）
  final int useCount;

  /// 最終使用日時（未使用なら null）
  final DateTime? lastUsedAt;

  /// 作成日時
  final DateTime createdAt;

  ExpenseTemplate({
    required this.id,
    required this.amount,
    required this.purpose,
    required this.category,
    required this.useCount,
    this.lastUsedAt,
    required this.createdAt,
  }) {
    // 不変条件は assert ではなく ArgumentError で強制する
    // （assert はリリースビルドで無効化され、破損データの全滅を招くため）。
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', '金額は正である必要がある');
    }
    if (purpose.trim().isEmpty) {
      throw ArgumentError.value(purpose, 'purpose', '用途を空にはできません');
    }
    if (category.trim().isEmpty) {
      throw ArgumentError.value(category, 'category', 'カテゴリを空にはできません');
    }
    if (useCount < 0) {
      throw ArgumentError.value(useCount, 'useCount', '使用回数は0以上である必要がある');
    }
  }

  /// 一部フィールドのみ変更した新しいテンプレートを返す。
  ExpenseTemplate copyWith({
    String? id,
    int? amount,
    String? purpose,
    String? category,
    int? useCount,
    DateTime? lastUsedAt,
    DateTime? createdAt,
  }) {
    return ExpenseTemplate(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      purpose: purpose ?? this.purpose,
      category: category ?? this.category,
      useCount: useCount ?? this.useCount,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// JSON から復元する（破損時は `null` を返して読み飛ばせる）。
  ///
  /// [raw] は信頼できない生データを想定するため、assert 由来の例外が
  /// 全滅を招かないよう、ここで明示的に検証してから構築する。
  static ExpenseTemplate? tryFromJson(Map<Object?, Object?> raw) {
    final id = raw['id'];
    final amount = raw['amount'];
    final purpose = raw['purpose'];
    final category = raw['category'];
    final useCount = raw['useCount'];
    final lastUsedAt = raw['lastUsedAt'];
    final createdAt = raw['createdAt'];
    if (id is! String || id.isEmpty) return null;
    if (amount is! int || amount <= 0) return null;
    if (purpose is! String || purpose.isEmpty) return null;
    if (category is! String || category.isEmpty) return null;
    if (useCount is! int || useCount < 0) return null;
    final DateTime? lastUsed;
    if (lastUsedAt == null) {
      lastUsed = null;
    } else if (lastUsedAt is String) {
      lastUsed = DateTime.tryParse(lastUsedAt);
    } else {
      return null;
    }
    if (createdAt is! String) return null;
    final created = DateTime.tryParse(createdAt);
    if (created == null) return null;
    return ExpenseTemplate(
      id: id,
      amount: amount,
      purpose: purpose,
      category: category,
      useCount: useCount,
      lastUsedAt: lastUsed,
      createdAt: created,
    );
  }

  /// JSON から復元する。
  ///
  /// 破損データに対しては [ArgumentError] を投げる。
  /// 永続化層での読み飛ばしには [tryFromJson] を使え。
  factory ExpenseTemplate.fromJson(Map<String, dynamic> json) {
    final template = tryFromJson(json);
    if (template == null) {
      throw ArgumentError.value(json, 'json', '破損したテンプレートデータ');
    }
    return template;
  }

  /// JSON に変換する。
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'purpose': purpose,
      'category': category,
      'useCount': useCount,
      'lastUsedAt': lastUsedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is ExpenseTemplate &&
      id == other.id &&
      amount == other.amount &&
      purpose == other.purpose &&
      category == other.category &&
      useCount == other.useCount &&
      lastUsedAt == other.lastUsedAt &&
      createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(
        id,
        amount,
        purpose,
        category,
        useCount,
        lastUsedAt,
        createdAt,
      );

  @override
  String toString() =>
      'ExpenseTemplate($id, $amount, $purpose, $category, $useCount)';
}
