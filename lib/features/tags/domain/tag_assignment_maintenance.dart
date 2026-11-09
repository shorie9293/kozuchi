/// タグ紐付けの退避と孤児紐付けの整理（純粋計算・I/Oなし）
///
/// 取引キーは `datetime|amount|purpose|category`（[TaggedTransaction.keyOfTransaction]）
/// で決定的に決まるため、削除した取引の紐付けをそのまま残すと、同じ内容の取引を
/// 再登録・CSV再取込した際に古いタグが黙って復活する。
/// 本ファイルは「削除時の退避」と「孤児（実在しない取引の紐付け）の刈り取り」を
/// 副作用なしで表現する。例外は投げない。
library;

/// 削除した取引のタグ紐付けの退避（Undo 復元用）。
class TagAssignmentBackup {
  /// 取引を一意に表すキー
  final String transactionKey;

  /// 退避したタグID列（空文字なし・重複なし・変更不可）
  final List<String> tagIds;

  const TagAssignmentBackup._({
    required this.transactionKey,
    required this.tagIds,
  });

  /// 正規化した退避を作る（空文字タグIDと重複を除去する）。
  factory TagAssignmentBackup.of({
    required String transactionKey,
    required List<String> tagIds,
  }) {
    final seen = <String>{};
    final distinct = <String>[];
    for (final tagId in tagIds) {
      if (tagId.isEmpty) continue;
      if (seen.add(tagId)) distinct.add(tagId);
    }
    return TagAssignmentBackup._(
      transactionKey: transactionKey,
      tagIds: List.unmodifiable(distinct),
    );
  }

  /// 退避したタグが1つも無いか。
  bool get isEmpty => tagIds.isEmpty;

  /// 指定キーの退避内容か。
  bool matches(String key) => transactionKey == key;

  @override
  String toString() => 'TagAssignmentBackup($transactionKey, $tagIds)';
}

/// 孤児タグ紐付け（実在しない取引への紐付け）の検出と刈り取り。
class TagAssignmentPrune {
  const TagAssignmentPrune._();

  /// 実在しない取引キー（孤児）をソート済みで返す。
  ///
  /// 空文字キーは対象外。例外は投げない。
  static List<String> orphanKeys({
    required Iterable<String> knownTransactionKeys,
    required Map<String, List<String>> assignments,
  }) {
    final known = <String>{};
    try {
      for (final key in knownTransactionKeys) {
        if (key.isNotEmpty) known.add(key);
      }
    } catch (_) {
      // 壊れた Iterable でも落とさない（孤児判定は空集合基準になる）
    }
    final orphans = <String>[];
    for (final key in assignments.keys) {
      if (key.isEmpty) continue;
      if (!known.contains(key)) orphans.add(key);
    }
    orphans.sort();
    return List.unmodifiable(orphans);
  }

  /// 孤児を取り除いた新しい紐付けマップを返す（元マップは破壊しない）。
  static Map<String, List<String>> prune({
    required Iterable<String> knownTransactionKeys,
    required Map<String, List<String>> assignments,
  }) {
    final known = <String>{};
    try {
      for (final key in knownTransactionKeys) {
        if (key.isNotEmpty) known.add(key);
      }
    } catch (_) {
      // 壊れた Iterable は空集合として扱う
    }
    final next = <String, List<String>>{};
    assignments.forEach((key, tagIds) {
      if (known.contains(key)) next[key] = List<String>.unmodifiable(tagIds);
    });
    return Map.unmodifiable(next);
  }

  /// 刈り取りを実行してよいか。
  ///
  /// 既知の取引が1件も無い（取得失敗・空データ）状態で刈り取ると
  /// 全紐付けが消える事故になるため、その場合は false を返す安全弁。
  static bool canPrune(Iterable<String> knownTransactionKeys) {
    try {
      for (final key in knownTransactionKeys) {
        if (key.isNotEmpty) return true;
      }
    } catch (_) {
      return false;
    }
    return false;
  }
}
