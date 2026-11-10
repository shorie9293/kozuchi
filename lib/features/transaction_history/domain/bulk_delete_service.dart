import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/transaction_history/domain/bulk_selection.dart';

/// 一括削除の逐次実行を担う純粋サービス。
///
/// Flutter にもリポジトリにも依存しない。1 件削除の実体は
/// [deleteOne] として注入され、個々の失敗（false 返却・例外）は握って
/// [BulkDeleteOutcome.failedIds] に載せ、残りの削除を継続する。
/// 呼び出し元には決して例外を投げない。
class BulkDeleteService {
  /// 1 件削除する関数。成功なら true。
  final Future<bool> Function(TransactionModel transaction) deleteOne;

  /// 個々の失敗を通知する任意のフック（ログ出力など）。
  final void Function(String message, Object error)? onError;

  const BulkDeleteService({
    required this.deleteOne,
    this.onError,
  });

  /// [targets] を先頭から 1 件ずつ順に削除し、結果を返す。
  ///
  /// 失敗しても残りを継続するため、部分成功の状態が起こり得る。
  /// [BulkDeleteOutcome.deletedItems] は成功分を元順序のまま返す（Undo 用）。
  Future<BulkDeleteOutcome> run(List<TransactionModel> targets) async {
    final deletedItems = <TransactionModel>[];
    final failedIds = <String>[];

    for (final target in targets) {
      final id = target.id ?? '';
      try {
        final succeeded = await deleteOne(target);
        if (succeeded) {
          deletedItems.add(target);
        } else {
          failedIds.add(id);
          onError?.call(
              '取引の削除に失敗しました（id: $id）', StateError('deleteOne returned false'));
        }
      } catch (error) {
        failedIds.add(id);
        onError?.call('取引の削除に失敗しました（id: $id）', error);
      }
    }

    return BulkDeleteOutcome(
      deleted: deletedItems.length,
      failed: failedIds.length,
      failedIds: List<String>.unmodifiable(failedIds),
      deletedItems: List<TransactionModel>.unmodifiable(deletedItems),
    );
  }
}
