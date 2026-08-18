import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/domain/services/expense_entry_recording_service.dart';
import 'package:kozuchi/domain/services/expense_repository.dart';
import 'package:kozuchi/domain/services/expense_repository_impl.dart';

void main() {
  group('ExpenseEntryRecordingService', () {
    late InMemoryExpenseRepository repository;
    late ExpenseEntryRecordingService service;

    setUp(() {
      repository = InMemoryExpenseRepository();
      service = ExpenseEntryRecordingService(
        repository: repository,
        clock: () => DateTime(2026, 6, 24, 12, 30),
      );
    });

    test('記録時にExpenseEntryが保存され、保存済みエントリを返す', () async {
      final entry = await service.record(
        amount: 500,
        category: '食費',
        note: 'ランチ',
      );

      expect(entry, isNotNull);
      expect(entry!.amount, 500);
      expect(entry.category, '食費');
      expect(entry.note, 'ランチ');
      expect(entry.date, DateTime(2026, 6, 24, 12, 30));
      expect(entry.id, isNotEmpty);

      expect(await repository.getEntryCount(), 1);
      final saved = await repository.getEntries(
        start: DateTime(2026, 6, 1),
        end: DateTime(2026, 6, 30),
      );
      expect(saved, hasLength(1));
      expect(saved.single.id, entry.id);
    });

    test('金額が0以下の場合は保存せずnullを返す', () async {
      final entry = await service.record(
        amount: 0,
        category: '食費',
      );
      expect(entry, isNull);
      expect(await repository.getEntryCount(), 0);
    });

    test('保存に失敗した場合はnullを返す（例外を伝播しない）', () async {
      final failing = _FailingExpenseRepository();
      final s = ExpenseEntryRecordingService(repository: failing);
      final entry = await s.record(amount: 100, category: 'その他');
      expect(entry, isNull);
    });
  });
}

class _FailingExpenseRepository implements ExpenseRepository {
  @override
  Future<List<ExpenseEntry>> getEntries({
    required DateTime start,
    required DateTime end,
  }) async =>
      [];

  @override
  Future<void> saveEntry(ExpenseEntry entry) async {
    throw Exception('save failed');
  }

  @override
  Future<void> saveEntries(List<ExpenseEntry> entries) async {
    throw Exception('save failed');
  }

  @override
  Future<int> getEntryCount() async => 0;

  @override
  Future<void> clearAll() async {}
}
