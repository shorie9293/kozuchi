import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/domain/services/expense_cloud_store.dart';
import 'package:kozuchi/domain/services/supabase_expense_repository.dart';

void main() {
  group('SupabaseExpenseRepository', () {
    late _FakeCloudStore cloudStore;
    String? userId = 'user-1';
    late SupabaseExpenseRepository repository;

    setUp(() {
      cloudStore = _FakeCloudStore();
      repository = SupabaseExpenseRepository(
        cloudStore: cloudStore,
        userIdProvider: () => userId,
      );
    });

    test('saveEntryはcloudStoreのsaveExpenseEntriesへuser_id付きで委譲する', () async {
      final entry = ExpenseEntry(
        id: 'id-1',
        amount: 500,
        category: '食費',
        date: DateTime(2026, 6, 24),
      );

      await repository.saveEntry(entry);

      expect(cloudStore.savedUserIds, ['user-1']);
      expect(cloudStore.savedEntries.single.id, 'id-1');
    });

    test('saveEntriesは複数件を一括保存する', () async {
      final entries = [
        ExpenseEntry(id: 'a', amount: 100, category: 'x', date: DateTime(2026)),
        ExpenseEntry(id: 'b', amount: 200, category: 'y', date: DateTime(2026)),
      ];

      await repository.saveEntries(entries);

      expect(cloudStore.savedEntries, hasLength(2));
      expect(cloudStore.savedUserIds, ['user-1']);
    });

    test('getEntriesは日付範囲で絞り込み、古い順に返す', () async {
      cloudStore.entries = [
        ExpenseEntry(id: 'old', amount: 100, category: 'x',
            date: DateTime(2026, 5, 31)),
        ExpenseEntry(id: 'mid', amount: 200, category: 'x',
            date: DateTime(2026, 6, 10)),
        ExpenseEntry(id: 'new', amount: 300, category: 'x',
            date: DateTime(2026, 6, 20)),
        ExpenseEntry(id: 'late', amount: 400, category: 'x',
            date: DateTime(2026, 7, 1)),
      ];

      final result = await repository.getEntries(
        start: DateTime(2026, 6, 1),
        end: DateTime(2026, 6, 30),
      );

      expect(result.map((e) => e.id).toList(), ['mid', 'new']);
    });

    test('getEntryCountはクラウドの全件数を返す', () async {
      cloudStore.entries = [
        ExpenseEntry(id: 'a', amount: 1, category: 'x', date: DateTime(2026)),
        ExpenseEntry(id: 'b', amount: 2, category: 'x', date: DateTime(2026)),
      ];

      expect(await repository.getEntryCount(), 2);
    });

    test('clearAllは例外なく安全に実行される（Supabase側はリセット不可のためno-op）', () async {
      cloudStore.entries = [
        ExpenseEntry(id: 'a', amount: 1, category: 'x', date: DateTime(2026)),
      ];

      await repository.clearAll();

      // 保存は呼ばれない（削除APIを持たないためno-op）
      expect(cloudStore.savedEntries, isEmpty);
    });

    test('userIdがnullの場合は保存せず何もしない', () async {
      userId = null;
      final entry = ExpenseEntry(
        id: 'id-1',
        amount: 500,
        category: '食費',
        date: DateTime(2026),
      );

      await repository.saveEntry(entry);

      expect(cloudStore.savedEntries, isEmpty);
    });

    test('userIdがnullの場合はloadせず空を返す', () async {
      userId = null;
      cloudStore.entries = [
        ExpenseEntry(id: 'a', amount: 1, category: 'x', date: DateTime(2026)),
      ];

      final result = await repository.getEntries(
        start: DateTime(2026),
        end: DateTime(2026, 12, 31),
      );

      expect(result, isEmpty);
      expect(cloudStore.loadCalls, 0);
    });
  });
}

class _FakeCloudStore implements ExpenseCloudStore {
  List<ExpenseEntry> entries = [];
  final List<ExpenseEntry> savedEntries = [];
  final List<String> savedUserIds = [];
  int clearedCount = 0;
  int loadCalls = 0;

  @override
  Future<void> saveExpenseEntries(
    List<ExpenseEntry> entries, {
    required String userId,
  }) async {
    savedEntries.addAll(entries);
    savedUserIds.add(userId);
  }

  @override
  Future<List<ExpenseEntry>> loadExpenseEntries({
    required String userId,
    DateTime? lastSyncAt,
  }) async {
    loadCalls++;
    return entries;
  }
}
