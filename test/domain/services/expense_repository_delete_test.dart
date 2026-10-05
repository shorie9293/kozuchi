import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/domain/services/expense_cloud_store.dart';
import 'package:kozuchi/domain/services/expense_repository_impl.dart';
import 'package:kozuchi/domain/services/supabase_expense_repository.dart';

ExpenseEntry _entry(String id, int amount, DateTime date) => ExpenseEntry(
      id: id,
      amount: amount,
      category: '食費',
      date: date,
      note: 'メモ$id',
    );

void main() {
  group('InMemoryExpenseRepository.deleteEntry', () {
    test('指定IDのエントリを削除する', () async {
      final repo = InMemoryExpenseRepository();
      await repo.saveEntries([
        _entry('a', 100, DateTime(2026, 10, 1)),
        _entry('b', 200, DateTime(2026, 10, 2)),
      ]);
      await repo.deleteEntry('a');
      expect(await repo.getEntryCount(), 1);
      final rest = await repo.getEntries(
        start: DateTime(2026, 10, 1),
        end: DateTime(2026, 10, 2),
      );
      expect(rest.single.id, 'b');
    });

    test('存在しないIDでも例外を出さず冪等', () async {
      final repo = InMemoryExpenseRepository();
      await repo.saveEntry(_entry('a', 100, DateTime(2026, 10, 1)));
      await repo.deleteEntry('missing');
      expect(await repo.getEntryCount(), 1);
    });

    test('getEntryById は該当エントリを返し、無ければ null', () async {
      final repo = InMemoryExpenseRepository();
      await repo.saveEntry(_entry('a', 100, DateTime(2026, 10, 1)));
      expect((await repo.getEntryById('a'))!.id, 'a');
      expect(await repo.getEntryById('zzz'), isNull);
    });
  });

  group('SharedPrefsExpenseRepository.deleteEntry', () {
    test('削除が永続化に到達する', () async {
      final written = <String, String>{};
      final repo = SharedPrefsExpenseRepository(
        getPrefs: () async => written,
        setString: (key, value) async => written[key] = value,
      );
      await repo.saveEntries([
        _entry('a', 100, DateTime(2026, 10, 1)),
        _entry('b', 200, DateTime(2026, 10, 2)),
      ]);
      await repo.deleteEntry('a');
      // 新しいインスタンス（＝再起動相当）から復元して確認
      final repo2 = SharedPrefsExpenseRepository(
        getPrefs: () async => written,
        setString: (key, value) async => written[key] = value,
      );
      expect(await repo2.getEntryCount(), 1);
      expect((await repo2.getEntryById('b'))!.id, 'b');
      expect(await repo2.getEntryById('a'), isNull);
    });

    test('存在しないIDの削除は書込を行わない', () async {
      final written = <String, String>{};
      var writes = 0;
      final repo = SharedPrefsExpenseRepository(
        getPrefs: () async => written,
        setString: (key, value) async {
          writes++;
          written[key] = value;
        },
      );
      await repo.saveEntry(_entry('a', 100, DateTime(2026, 10, 1)));
      writes = 0;
      await repo.deleteEntry('missing');
      expect(writes, 0);
    });
  });

  group('SupabaseExpenseRepository.deleteEntry', () {
    test('クラウドストアの削除に委譲する（user_id 付き）', () async {
      final store = _RecordingCloudStore()
        ..entries = [
          _entry('a', 100, DateTime(2026, 10, 1)),
          _entry('b', 200, DateTime(2026, 10, 2)),
        ];
      final repo = SupabaseExpenseRepository(
        cloudStore: store,
        userIdProvider: () => 'user-1',
      );
      await repo.deleteEntry('a');
      expect(store.deletedIds, ['a']);
      expect(store.deletedUserIds, ['user-1']);
      final rest = await repo.getEntries(
        start: DateTime(2026, 10, 1),
        end: DateTime(2026, 10, 2),
      );
      expect(rest.single.id, 'b');
    });

    test('未認証（userId null）では削除しない', () async {
      final store = _RecordingCloudStore()
        ..entries = [_entry('a', 100, DateTime(2026, 10, 1))];
      final repo = SupabaseExpenseRepository(
        cloudStore: store,
        userIdProvider: () => null,
      );
      await repo.deleteEntry('a');
      expect(store.deletedIds, isEmpty);
      expect(store.entries.single.id, 'a');
    });
  });
}

class _RecordingCloudStore implements ExpenseCloudStore {
  List<ExpenseEntry> entries = [];
  final List<String> deletedIds = [];
  final List<String> deletedUserIds = [];

  @override
  Future<void> saveExpenseEntries(
    List<ExpenseEntry> entries, {
    required String userId,
  }) async {
    for (final entry in entries) {
      final index = this.entries.indexWhere((e) => e.id == entry.id);
      if (index >= 0) {
        this.entries[index] = entry;
      } else {
        this.entries.add(entry);
      }
    }
  }

  @override
  Future<List<ExpenseEntry>> loadExpenseEntries({
    required String userId,
    DateTime? lastSyncAt,
  }) async =>
      entries;

  @override
  Future<void> deleteExpenseEntry(String id, {required String userId}) async {
    entries = entries.where((e) => e.id != id).toList();
    deletedIds.add(id);
    deletedUserIds.add(userId);
  }
}
