import '../../core/infrastructure/expense_entries_load_result.dart';
import '../models/expense_entry.dart';

/// Supabase の支出明細ストアに対する抽象インターフェース。
///
/// [CloudSyncService] がこの契約を実装する。テストではメモリ実装を
/// 注入することで、実際の Supabase に触れずに検証できる。
abstract class ExpenseCloudStore {
  /// 支出明細を upsert 保存する（ID ベースのマージ）。
  Future<void> saveExpenseEntries(
    List<ExpenseEntry> entries, {
    required String userId,
  });

  /// 指定ユーザーの全支出明細を取得する（date 降順）。
  Future<List<ExpenseEntry>> loadExpenseEntries({
    required String userId,
    DateTime? lastSyncAt,
  });

  /// 指定IDの支出明細を削除する（冪等・存在しなくてもエラーにしない）。
  Future<void> deleteExpenseEntry(String id, {required String userId});
}

/// 読込結果（読み飛ばし件数・照合可否）付きで取得できるストア。
///
/// Dart の `implements` は既定実装を継承しないため、[ExpenseCloudStore] へ
/// 具象メソッドを足すと既存のフェイク実装がコンパイル不能になる。
/// そこで「壊れた行を数えられる」能力だけを別インタフェースとして切り出す。
/// 実装していないストアは [ExpenseCloudStore.loadExpenseEntries] に
/// フォールバックし、`skippedCount: 0` / `canVerify: true` として扱う。
abstract class ExpenseEntriesResultSource {
  /// 読込結果を「読み飛ばし件数・照合可否」付きで返す。**throw しない**。
  Future<ExpenseEntriesLoadResult> loadExpenseEntriesResult({
    required String userId,
    DateTime? lastSyncAt,
  });
}
