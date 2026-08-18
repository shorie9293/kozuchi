import '../models/expense_entry.dart';
import 'expense_cloud_store.dart';
import 'expense_repository.dart';

/// Supabase を永続化先に持つ [ExpenseRepository] 実装。
///
/// [ExpenseCloudStore]（= [CloudSyncService]）へ委譲し、`expense_entries`
/// テーブルとの読み書きを行う。user_id は [userIdProvider] から動的に取得し、
/// 未認証（null）の間は何も保存/取得しない。
class SupabaseExpenseRepository implements ExpenseRepository {
  final ExpenseCloudStore _cloudStore;
  final String? Function() _userIdProvider;

  SupabaseExpenseRepository({
    required ExpenseCloudStore cloudStore,
    required String? Function() userIdProvider,
  })  : _cloudStore = cloudStore,
        _userIdProvider = userIdProvider;

  String? get _userId => _userIdProvider();

  @override
  Future<void> saveEntry(ExpenseEntry entry) => saveEntries([entry]);

  @override
  Future<void> saveEntries(List<ExpenseEntry> entries) async {
    final userId = _userId;
    if (userId == null) return;
    await _cloudStore.saveExpenseEntries(entries, userId: userId);
  }

  @override
  Future<List<ExpenseEntry>> getEntries({
    required DateTime start,
    required DateTime end,
  }) async {
    final userId = _userId;
    if (userId == null) return [];
    final all = await _cloudStore.loadExpenseEntries(userId: userId);
    final startDay = _dayOnly(start);
    final endDay = _dayOnly(end);
    return all.where((e) {
      final entryDay = _dayOnly(e.date);
      return !entryDay.isBefore(startDay) && !entryDay.isAfter(endDay);
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  Future<int> getEntryCount() async {
    final userId = _userId;
    if (userId == null) return 0;
    final all = await _cloudStore.loadExpenseEntries(userId: userId);
    return all.length;
  }

  @override
  Future<void> clearAll() async {
    // Supabase はリセット削除 API を持たないため no-op（安全に何もしない）。
    return;
  }

  DateTime _dayOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}
