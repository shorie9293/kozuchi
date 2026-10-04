import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/income/domain/models/income_entry.dart';
import 'package:kozuchi/features/income/domain/services/income_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('IncomeEntry', () {
    test('負金額・空収入源は ArgumentError', () {
      expect(
        () => IncomeEntry(
            id: 'i', amount: 0, source: '給与', date: DateTime(2026, 10, 1)),
        throwsArgumentError,
      );
      expect(
        () => IncomeEntry(
            id: 'i', amount: -5, source: '給与', date: DateTime(2026, 10, 1)),
        throwsArgumentError,
      );
      expect(
        () => IncomeEntry(
            id: 'i', amount: 100, source: '  ', date: DateTime(2026, 10, 1)),
        throwsArgumentError,
      );
    });

    test('JSON 往復で値が保存される', () {
      final entry = IncomeEntry(
        id: 'inc_1',
        amount: 30000,
        source: '給与',
        date: DateTime(2026, 10, 1, 9, 30),
        note: '十月の給料',
      );
      final restored = IncomeEntry.fromJson(entry.toJson());
      expect(restored.id, 'inc_1');
      expect(restored.amount, 30000);
      expect(restored.source, '給与');
      expect(restored.date, entry.date);
      expect(restored.note, '十月の給料');
    });
  });

  group('InMemoryIncomeRepository', () {
    test('保存と取得（date 昇順）・上書き・クリア', () async {
      final repo = InMemoryIncomeRepository();
      final later = IncomeEntry(
          id: 'b', amount: 200, source: '副業', date: DateTime(2026, 10, 5));
      final earlier = IncomeEntry(
          id: 'a', amount: 100, source: '給与', date: DateTime(2026, 10, 1));

      await repo.saveEntry(later);
      await repo.saveEntry(earlier);

      var entries = await repo.getAllEntries();
      expect(entries.map((e) => e.id), ['a', 'b']);

      // 同ID上書き
      await repo.saveEntry(IncomeEntry(
          id: 'b', amount: 250, source: '副業', date: DateTime(2026, 10, 5)));
      entries = await repo.getAllEntries();
      expect(entries.length, 2);
      expect(entries.firstWhere((e) => e.id == 'b').amount, 250);

      await repo.clearAll();
      expect(await repo.getAllEntries(), isEmpty);
    });
  });

  group('SharedPreferencesIncomeRepository', () {
    test('保存・復元・破損JSONは空リストへフォールバック', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPreferencesIncomeRepository(prefs);

      await repo.saveEntry(IncomeEntry(
          id: 'a', amount: 100, source: '給与', date: DateTime(2026, 10, 1)));
      await repo.saveEntry(IncomeEntry(
          id: 'b', amount: 300, source: '贈与', date: DateTime(2026, 10, 3)));

      final entries = await repo.getAllEntries();
      expect(entries.length, 2);
      expect(entries.first.id, 'a');

      // 別インスタンス（再起動相当）でも復元される
      final repo2 = SharedPreferencesIncomeRepository(prefs);
      final restored = await repo2.getAllEntries();
      expect(restored.map((e) => e.id).toList(), ['a', 'b']);

      // 破損JSON → 空リスト
      await prefs.setString('income_entries', '{{{broken');
      expect(await repo.getAllEntries(), isEmpty);
    });
  });

  group('NoopIncomeRepository', () {
    test('何も保存せず常に空を返す', () async {
      const repo = NoopIncomeRepository();
      await repo.saveEntry(IncomeEntry(
          id: 'a', amount: 100, source: '給与', date: DateTime(2026, 10, 1)));
      expect(await repo.getAllEntries(), isEmpty);
      await repo.clearAll();
      expect(await repo.getAllEntries(), isEmpty);
    });
  });
}
