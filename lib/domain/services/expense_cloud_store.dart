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
}
