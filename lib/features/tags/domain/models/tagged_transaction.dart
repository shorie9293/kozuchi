import 'package:kozuchi/domain/models/transaction_model.dart';

/// 取引とタグの紐付け
///
/// 取引そのものにタグを書き込むと Supabase 側スキーマ変更が必要になるため、
/// 「取引を一意に表すキー（[transactionKey]）→ タグID列」という形で
/// ローカルにのみ永続化する。
class TaggedTransaction {
  /// 取引を一意に表すキー
  final String transactionKey;

  /// 紐付くタグIDの一覧（重複なし）
  final List<String> tagIds;

  const TaggedTransaction({
    required this.transactionKey,
    this.tagIds = const [],
  });

  /// 取引の各字段からキー文字列を生成する。
  ///
  /// `datetime|amount|purpose|category` 形式。
  static String keyFor({
    required String datetime,
    required int amount,
    required String purpose,
    required String category,
  }) {
    return '$datetime|$amount|$purpose|$category';
  }

  /// [TransactionModel] からキー文字列を生成する。
  static String keyOfTransaction(TransactionModel transaction) {
    return keyFor(
      datetime: transaction.datetime,
      amount: transaction.amount,
      purpose: transaction.purpose,
      category: transaction.category,
    );
  }

  /// [TransactionModel] から紐付けレコードを生成する。
  factory TaggedTransaction.of(
    TransactionModel transaction, {
    List<String> tagIds = const [],
  }) {
    return TaggedTransaction(
      transactionKey: keyOfTransaction(transaction),
    ).copyWith(tagIds: tagIds);
  }

  /// 指定タグが紐付いているか。
  bool hasTag(String tagId) => tagIds.contains(tagId);

  /// タグが1つも紐付いていないか。
  bool get isUntagged => tagIds.isEmpty;

  /// タグ列を差し替えた新しいレコードを返す（重複は除去）。
  TaggedTransaction copyWith({List<String>? tagIds}) {
    return TaggedTransaction(
      transactionKey: transactionKey,
      tagIds: List.unmodifiable(_dedupe(tagIds ?? this.tagIds)),
    );
  }

  /// JSON から復元。
  factory TaggedTransaction.fromJson(Map<String, dynamic> json) {
    final raw = json['tags'];
    final tags = <String>[];
    if (raw is List) {
      for (final value in raw) {
        if (value is String && value.isNotEmpty) tags.add(value);
      }
    }
    return TaggedTransaction(
      transactionKey: json['key'] as String? ?? '',
      tagIds: List.unmodifiable(_dedupe(tags)),
    );
  }

  /// JSON に変換。
  Map<String, dynamic> toJson() {
    return {
      'key': transactionKey,
      'tags': tagIds,
    };
  }

  static List<String> _dedupe(List<String> values) {
    final seen = <String>{};
    final result = <String>[];
    for (final value in values) {
      if (value.isEmpty) continue;
      if (seen.add(value)) result.add(value);
    }
    return result;
  }

  @override
  bool operator ==(Object other) =>
      other is TaggedTransaction &&
      transactionKey == other.transactionKey &&
      _listEquals(tagIds, other.tagIds);

  @override
  int get hashCode => Object.hash(transactionKey, Object.hashAll(tagIds));

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() => 'TaggedTransaction($transactionKey, $tagIds)';
}
