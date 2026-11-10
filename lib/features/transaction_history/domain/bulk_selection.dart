import 'dart:collection';

import 'package:kozuchi/domain/models/transaction_model.dart';

/// 取引履歴の一括操作で「どの取引が選ばれているか」を表す純粋値オブジェクト。
///
/// 内部は挿入順を保つ [LinkedHashSet] で、外部には unmodifiable な
/// [ids] としてのみ公開する。[toggle] / [addAll] / [clear] はいずれも
/// 新しいインスタンスを返し、元インスタンスは破壊しない
/// （Riverpod の状態更新で差分検知できるようにするため）。
class BulkSelection {
  final Set<String> _ids;

  /// 何も選択していない状態。
  const BulkSelection.empty() : _ids = const <String>{};

  const BulkSelection._(this._ids);

  /// [ids] を挿入順のまま選択状態にする。重複は 1 件に畳まれる。
  factory BulkSelection.of(Iterable<String> ids) {
    return BulkSelection._(
      UnmodifiableSetView<String>(LinkedHashSet<String>.of(ids)),
    );
  }

  /// 1 件以上選択されているか。
  bool get isSelecting => _ids.isNotEmpty;

  /// 選択件数。
  int get count => _ids.length;

  /// 選択中の取引 ID を挿入順で返す。返り値は変更不可。
  List<String> get ids => List<String>.unmodifiable(_ids);

  /// [id] が選択されているか。
  bool contains(String id) => _ids.contains(id);

  /// [id] の選択状態を反転した新しい選択を返す（追加／削除）。
  BulkSelection toggle(String id) {
    final next = LinkedHashSet<String>.of(_ids);
    if (!next.remove(id)) {
      next.add(id);
    }
    return BulkSelection._(UnmodifiableSetView<String>(next));
  }

  /// [ids] を既存選択に追加した新しい選択を返す。既存順を保ち重複は足さない。
  ///
  /// 「表示中の取引をすべて選択」は、絞込で入れ替わる visible の集合に対して
  /// 呼ばれる想定のため、既存選択は保持したまま追加する（[addAll] と同義）。
  BulkSelection selectAll(Iterable<String> ids) {
    final next = LinkedHashSet<String>.of(_ids);
    next.addAll(ids);
    return BulkSelection._(UnmodifiableSetView<String>(next));
  }

  /// 全解除した新しい選択を返す。
  BulkSelection clear() => const BulkSelection.empty();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! BulkSelection) return false;
    if (other._ids.length != _ids.length) return false;
    return _ids.every(other._ids.contains);
  }

  @override
  int get hashCode => Object.hashAllUnordered(_ids);

  @override
  String toString() => 'BulkSelection(${_ids.join(', ')})';
}

/// 一括削除の実行計画。
///
/// [toDelete] は実在する取引のみを [visible] の元順序で保持する（Undo 復元順の
/// 安定性のため）。[unknownIds] は選択されたが表示中に存在しない ID で、
/// 画面側が「絞込外／既に消えている」ことを無視できるようにするための情報。
class BulkDeletePlan {
  /// 実際に削除する取引。[visible] の元順序を保つ。
  final List<TransactionModel> toDelete;

  /// 選択されたが [visible] に存在しない ID。
  final List<String> unknownIds;

  const BulkDeletePlan({
    required this.toDelete,
    required this.unknownIds,
  });

  @override
  String toString() =>
      'BulkDeletePlan(toDelete: ${toDelete.length}, unknown: $unknownIds)';
}

/// [selection] を [visible]（画面に表示中の取引）に照合して一括削除の計画を組み立てる。
///
/// 照合先を「表示中の集合」に限定することで、絞込中に一括削除しても
/// 絞込外の取引を巻き込まないことを保証する。[visible] に無い選択 ID は
/// [BulkDeletePlan.unknownIds] に退避され、削除対象にはならない。
BulkDeletePlan buildBulkDeletePlan({
  required List<TransactionModel> visible,
  required BulkSelection selection,
}) {
  final toDelete = <TransactionModel>[];
  final known = <String>{};
  for (final transaction in visible) {
    final id = transaction.id;
    if (id == null) continue; // ID の無い取引は選択・削除の対象外
    known.add(id);
    if (selection.contains(id)) {
      toDelete.add(transaction);
    }
  }
  final unknownIds = selection.ids.where((id) => !known.contains(id)).toList();
  return BulkDeletePlan(toDelete: toDelete, unknownIds: unknownIds);
}

/// 一括削除の結果（throw しない結果型）。
///
/// [deletedItems] は削除に成功した取引を**元順序のまま**保持する
/// （Undo 復元の順序安定性のため）。
class BulkDeleteOutcome {
  /// 削除に成功した件数。
  final int deleted;

  /// 削除に失敗した件数。
  final int failed;

  /// 削除に失敗した取引 ID（対象順）。
  final List<String> failedIds;

  /// 削除に成功した取引（対象順）。
  final List<TransactionModel> deletedItems;

  const BulkDeleteOutcome({
    required this.deleted,
    required this.failed,
    required this.failedIds,
    required this.deletedItems,
  });

  /// 全件成功したか。
  bool get isComplete => failed == 0;

  @override
  String toString() => 'BulkDeleteOutcome(deleted: $deleted, failed: $failed)';
}
