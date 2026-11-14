import '../../core/time/local_calendar_date.dart';
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

  /// 直近の読込で型不整合により読み飛ばした行数。
  ///
  /// 画面側が「静かに件数が減った」ことに気づけるよう公開する
  /// （[ExpenseRepository] インタフェースには足さない — 既存実装が壊れるため）。
  int lastSkippedCount = 0;

  /// 直近の読込で照合できたか（false は応答がリストでなかった等）。
  bool lastCanVerify = true;

  String? get _userId => _userIdProvider();

  /// 読込結果を適用し、[lastSkippedCount] / [lastCanVerify] を更新する。
  ///
  /// 壊れた行を数えられるストア（[ExpenseEntriesResultSource]）なら結果付きで、
  /// そうでなければ従来どおり件数のみで読む（既存フェイクとの互換）。
  Future<List<ExpenseEntry>> _loadAll(String userId) async {
    final store = _cloudStore;
    if (store is ExpenseEntriesResultSource) {
      // 無関係なインタフェース間なので型昇格は効かない（明示的に扱う）。
      final source = store as ExpenseEntriesResultSource;
      final result = await source.loadExpenseEntriesResult(userId: userId);
      lastSkippedCount = result.skippedCount;
      lastCanVerify = result.canVerify;
      return result.entries;
    }
    lastSkippedCount = 0;
    lastCanVerify = true;
    return store.loadExpenseEntries(userId: userId);
  }

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
    final all = await _loadAll(userId);
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
    final all = await _loadAll(userId);
    return all.length;
  }

  @override
  Future<void> clearAll() async {
    // Supabase はリセット削除 API を持たないため no-op（安全に何もしない）。
    return;
  }

  @override
  Future<void> deleteEntry(String id) async {
    final userId = _userId;
    if (userId == null) return;
    await _cloudStore.deleteExpenseEntry(id, userId: userId);
  }

  @override
  Future<ExpenseEntry?> getEntryById(String id) async {
    final userId = _userId;
    if (userId == null) return null;
    final all = await _loadAll(userId);
    for (final entry in all) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  DateTime _dayOnly(DateTime dt) => localCalendarDate(dt);
}
