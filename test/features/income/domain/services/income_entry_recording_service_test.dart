import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/income/domain/models/income_entry.dart';
import 'package:kozuchi/features/income/domain/services/income_entry_recording_service.dart';
import 'package:kozuchi/features/income/domain/services/income_repository.dart';

void main() {
  group('IncomeEntryRecordingService.record', () {
    test('有効な収入を保存して保存済みエントリを返す', () async {
      final repo = InMemoryIncomeRepository();
      final service = IncomeEntryRecordingService(
        repository: repo,
        clock: () => DateTime(2026, 10, 4, 12),
      );

      final saved = await service.record(
        amount: 30000,
        source: '給与',
        note: '十月',
      );

      expect(saved, isNotNull);
      expect(saved!.amount, 30000);
      expect(saved.source, '給与');
      expect(saved.date, DateTime(2026, 10, 4, 12));
      expect(saved.note, '十月');
      expect((await repo.getAllEntries()).length, 1);
    });

    test('無効入力（0以下・空収入源）は保存せず null', () async {
      final repo = InMemoryIncomeRepository();
      final service = IncomeEntryRecordingService(repository: repo);

      expect(await service.record(amount: 0, source: '給与'), isNull);
      expect(await service.record(amount: -1, source: '給与'), isNull);
      expect(await service.record(amount: 100, source: '   '), isNull);
      expect(await repo.getAllEntries(), isEmpty);
    });

    test('保存失敗は例外を伝播せず null を返す（防御）', () async {
      final service = IncomeEntryRecordingService(
        repository: _ThrowingRepository(),
      );
      expect(
        await service.record(amount: 100, source: '給与'),
        isNull,
      );
    });
  });
}

class _ThrowingRepository implements IncomeRepository {
  @override
  Future<List<IncomeEntry>> getAllEntries() async => const [];

  @override
  Future<void> saveEntry(IncomeEntry entry) async {
    throw Exception('保存失敗');
  }

  @override
  Future<void> clearAll() async {}
}
