/// 単一スロットの Undo バッファ。
///
/// 「直前の1操作だけを取り消せる」用途に特化した純粋なデータ構造。
/// Flutter にもリポジトリにも依存しない（ジェネリック・同期のみ）。
///
/// 使い方:
/// ```dart
/// final buffer = UndoBuffer<TransactionModel>();
/// buffer.push(deleted);          // 削除直前に保持
/// if (buffer.canUndo) {
///   final restored = buffer.take(); // 一度だけ取り出せる
///   ...
/// }
/// ```
///
/// [take] は値を取り出した時点でバッファを空にするため、
/// 同じ値を二度復元することはできない（二重復元の防止）。
class UndoBuffer<T> {
  T? _item;

  /// [item] を保持し、直前に保持していた値を返す（初回・空なら null）。
  ///
  /// 保持できるのは常に1件のみで、古い値は破棄される。
  T? push(T item) {
    final previous = _item;
    _item = item;
    return previous;
  }

  /// 取り消せる値が保持されているか。
  bool get canUndo => _item != null;

  /// 保持値を取り出してバッファを空にする。
  ///
  /// 2回目以降は null を返す（一度だけ取り出し可能）。
  T? take() {
    final item = _item;
    _item = null;
    return item;
  }

  /// バッファを空にする（保持値は破棄）。
  void clear() {
    _item = null;
  }

  /// 保持値を取り出さずに参照する（空なら null）。
  T? peek() => _item;
}
