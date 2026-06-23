import 'package:test/test.dart';
import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/domain/models/aggregation_result.dart';
import 'package:kozuchi/domain/services/expense_repository.dart';
import 'package:kozuchi/domain/services/expense_repository_impl.dart';
import 'package:kozuchi/domain/services/expense_aggregation_service.dart';

void main() {
  // ── ExpenseEntry model ──
  group('ExpenseEntry', () {
    test('creates from constructor', () {
      final entry = ExpenseEntry(
        id: 'e1',
        amount: 1000,
        category: '食費',
        date: DateTime(2026, 6, 22),
      );
      expect(entry.id, 'e1');
      expect(entry.amount, 1000);
      expect(entry.category, '食費');
      expect(entry.date, DateTime(2026, 6, 22));
      expect(entry.note, isNull);
      expect(entry.receiptImagePath, isNull);
    });

    test('asserts amount > 0', () {
      expect(
        () => ExpenseEntry(id: 'e', amount: 0, category: 'c', date: DateTime(2026)),
        throwsA(isA<AssertionError>()),
      );
    });

    test('JSON serialization roundtrip', () {
      final entry = ExpenseEntry(
        id: 'e1',
        amount: 2500,
        category: '交通費',
        date: DateTime(2026, 6, 22, 14, 30),
        note: '電車',
        receiptImagePath: '/path/to/img.jpg',
      );
      final json = entry.toJson();
      final restored = ExpenseEntry.fromJson(json);
      expect(restored.id, entry.id);
      expect(restored.amount, entry.amount);
      expect(restored.category, entry.category);
      expect(restored.date, entry.date);
      expect(restored.note, entry.note);
      expect(restored.receiptImagePath, entry.receiptImagePath);
    });

    test('fromJson handles missing optional fields', () {
      final entry = ExpenseEntry.fromJson({
        'id': 'e1',
        'amount': 500,
        'category': '食費',
        'date': '2026-06-22T00:00:00.000',
      });
      expect(entry.note, isNull);
      expect(entry.receiptImagePath, isNull);
    });

    test('equality by id', () {
      final a = ExpenseEntry(id: 'e1', amount: 100, category: 'a', date: DateTime(2026));
      final b = ExpenseEntry(id: 'e1', amount: 200, category: 'b', date: DateTime(2025));
      expect(a, equals(b));
    });
  });

  // ── AggregationResult models ──
  group('AggregationResult models', () {
    test('CategoryTotal toJson', () {
      final ct = CategoryTotal(category: '食費', amount: 5000, percentage: 33.3);
      final json = ct.toJson();
      expect(json['category'], '食費');
      expect(json['amount'], 5000);
      expect(json['percentage'], 33.3);
    });

    test('DailyTotal date formatting', () {
      final dt = DailyTotal(date: DateTime(2026, 6, 22), amount: 3000);
      final json = dt.toJson();
      expect(json['date'], '2026-06-22');
      expect(json['amount'], 3000);
    });

    test('PeriodInfo toJson', () {
      final pi = PeriodInfo(
        start: DateTime(2026, 6, 15),
        end: DateTime(2026, 6, 21),
        type: 'weekly',
      );
      final json = pi.toJson();
      expect(json['type'], 'weekly');
      expect(json['start'], '2026-06-15');
      expect(json['end'], '2026-06-21');
    });

    test('AggregationResult full toJson', () {
      final result = AggregationResult(
        period: PeriodInfo(start: DateTime(2026, 6, 15), end: DateTime(2026, 6, 21), type: 'weekly'),
        previousPeriod: PeriodInfo(start: DateTime(2026, 6, 8), end: DateTime(2026, 6, 14), type: 'weekly'),
        current: PeriodAggregation(
          total: 50000,
          byCategory: [CategoryTotal(category: '食費', amount: 20000, percentage: 40.0)],
          byDay: [DailyTotal(date: DateTime(2026, 6, 15), amount: 10000)],
        ),
        previous: PeriodAggregation(
          total: 45000,
          byCategory: [CategoryTotal(category: '食費', amount: 18000, percentage: 40.0)],
          byDay: [DailyTotal(date: DateTime(2026, 6, 8), amount: 9000)],
        ),
        comparison: PeriodComparison(
          totalChange: 5000,
          totalChangePercent: 11.1,
          byCategoryChanges: [
            CategoryComparison(
              category: '食費', currentAmount: 20000, previousAmount: 18000,
              change: 2000, changePercent: 11.1,
            )
          ],
        ),
      );
      final json = result.toJson();
      expect(json['period']['type'], 'weekly');
      expect(json['current']['total'], 50000);
      expect(json['previous']['total'], 45000);
      expect(json['comparison']['totalChange'], 5000);
    });
  });

  // ── InMemoryExpenseRepository ──
  group('InMemoryExpenseRepository', () {
    late ExpenseRepository repo;

    setUp(() {
      repo = InMemoryExpenseRepository();
    });

    test('starts empty', () async {
      expect(await repo.getEntryCount(), 0);
    });

    test('saves and retrieves entries', () async {
      final entry = ExpenseEntry(id: 'e1', amount: 1000, category: '食費', date: DateTime(2026, 6, 22));
      await repo.saveEntry(entry);
      expect(await repo.getEntryCount(), 1);

      final entries = await repo.getEntries(
        start: DateTime(2026, 6, 20),
        end: DateTime(2026, 6, 24),
      );
      expect(entries.length, 1);
      expect(entries[0].id, 'e1');
    });

    test('date range filtering', () async {
      await repo.saveEntries([
        ExpenseEntry(id: 'e1', amount: 1000, category: '食費', date: DateTime(2026, 6, 20)),
        ExpenseEntry(id: 'e2', amount: 2000, category: '交通費', date: DateTime(2026, 6, 22)),
        ExpenseEntry(id: 'e3', amount: 3000, category: '娯楽', date: DateTime(2026, 6, 25)),
      ]);

      final weekEntries = await repo.getEntries(
        start: DateTime(2026, 6, 21),
        end: DateTime(2026, 6, 23),
      );
      expect(weekEntries.length, 1);
      expect(weekEntries[0].id, 'e2');
    });

    test('date range includes boundaries', () async {
      await repo.saveEntry(
        ExpenseEntry(id: 'e1', amount: 1000, category: '食費', date: DateTime(2026, 6, 22, 14, 30)),
      );

      final entries = await repo.getEntries(
        start: DateTime(2026, 6, 22),
        end: DateTime(2026, 6, 22),
      );
      expect(entries.length, 1); // 時刻を無視して同日なら含める
    });

    test('update existing entry', () async {
      await repo.saveEntry(ExpenseEntry(id: 'e1', amount: 1000, category: '食費', date: DateTime(2026, 6, 22)));
      await repo.saveEntry(ExpenseEntry(id: 'e1', amount: 2000, category: '食費', date: DateTime(2026, 6, 22)));
      expect(await repo.getEntryCount(), 1);

      final entries = await repo.getEntries(start: DateTime(2026, 6, 1), end: DateTime(2026, 6, 30));
      expect(entries[0].amount, 2000);
    });

    test('clearAll removes everything', () async {
      await repo.saveEntry(ExpenseEntry(id: 'e1', amount: 1000, category: '食費', date: DateTime(2026, 6, 22)));
      await repo.clearAll();
      expect(await repo.getEntryCount(), 0);
    });
  });

  // ── ExpenseAggregationService ──
  group('ExpenseAggregationService', () {
    late InMemoryExpenseRepository repo;
    late ExpenseAggregationService service;

    setUp(() {
      repo = InMemoryExpenseRepository();
      service = ExpenseAggregationService(repo);
    });

    String _formatDate(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    /// テスト用の支出データを1週間分投入するヘルパー
    Future<void> _seedWeek(DateTime monday, List<({String category, int amount, int dayOffset})> data) async {
      final entries = <ExpenseEntry>[];
      for (var i = 0; i < data.length; i++) {
        final d = data[i];
        entries.add(ExpenseEntry(
          id: '${_formatDate(monday)}_$i',
          amount: d.amount,
          category: d.category,
          date: monday.add(Duration(days: d.dayOffset)),
        ));
      }
      await repo.saveEntries(entries);
    }

    test('weekly summary: basic aggregation', () async {
      // 6月15日(月)〜6月21日(日) の週にデータ投入
      final mon = DateTime(2026, 6, 15);
      await _seedWeek(mon, [
        (category: '食費', amount: 3000, dayOffset: 0),   // 月
        (category: '交通費', amount: 1000, dayOffset: 0),   // 月
        (category: '食費', amount: 2000, dayOffset: 2),     // 水
        (category: '娯楽', amount: 5000, dayOffset: 3),     // 木
        (category: '食費', amount: 1000, dayOffset: 6),     // 日
      ]);

      final result = await service.getWeeklySummary(DateTime(2026, 6, 18)); // 木曜を基準

      // 期間チェック
      expect(result.period.start, DateTime(2026, 6, 15));
      expect(result.period.end, DateTime(2026, 6, 21));
      expect(result.period.type, 'weekly');

      // 総額チェック
      expect(result.current.total, 3000 + 1000 + 2000 + 5000 + 1000); // 12000
      expect(result.previous.total, 0); // 前週はデータなし

      // カテゴリ別チェック
      expect(result.current.byCategory.length, 3);
      expect(result.current.byCategory[0].category, '食費'); // 金額降順: 食費=6000
      expect(result.current.byCategory[0].amount, 6000);
      expect(result.current.byCategory[0].percentage, closeTo(50.0, 0.1));

      // 日別チェック
      expect(result.current.byDay.length, 4); // 4日分のエントリ

      // 比較チェック
      expect(result.comparison.totalChange, 12000);
      expect(result.comparison.totalChangePercent, 100.0); // 前週0なので+100%
    });

    test('weekly summary: comparison with previous week', () async {
      // 今週: 6/15(月)〜6/21(日)
      final thisMon = DateTime(2026, 6, 15);
      await _seedWeek(thisMon, [
        (category: '食費', amount: 5000, dayOffset: 1),
        (category: '交通費', amount: 2000, dayOffset: 2),
      ]);

      // 前週: 6/8(月)〜6/14(日)
      final prevMon = DateTime(2026, 6, 8);
      await _seedWeek(prevMon, [
        (category: '食費', amount: 3000, dayOffset: 1),
        (category: '娯楽', amount: 4000, dayOffset: 3),
      ]);

      final result = await service.getWeeklySummary(DateTime(2026, 6, 18));

      // 前週の値チェック
      expect(result.previous.total, 7000);
      expect(result.previous.byCategory.length, 2);
      expect(result.previousPeriod.start, DateTime(2026, 6, 8));
      expect(result.previousPeriod.end, DateTime(2026, 6, 14));

      // 比較
      expect(result.comparison.totalChange, 0); // 7000 vs 7000
      expect(result.comparison.totalChangePercent, 0.0);
      expect(result.comparison.byCategoryChanges.length, 3); // 食費, 交通費, 娯楽
    });

    test('weekly summary: monday boundary', () async {
      final mon = DateTime(2026, 6, 15);
      await _seedWeek(mon, [
        (category: '食費', amount: 1000, dayOffset: 0), // 月曜
      ]);

      // 月曜日を基準にした場合
      final result = await service.getWeeklySummary(DateTime(2026, 6, 15));
      expect(result.period.start, DateTime(2026, 6, 15));
      expect(result.period.end, DateTime(2026, 6, 21));
      expect(result.current.total, 1000);
    });

    test('weekly summary: sunday boundary', () async {
      final mon = DateTime(2026, 6, 15);
      await _seedWeek(mon, [
        (category: '食費', amount: 1000, dayOffset: 6), // 日曜
      ]);

      // 日曜日を基準にした場合
      final result = await service.getWeeklySummary(DateTime(2026, 6, 21));
      expect(result.current.total, 1000);
    });

    test('monthly summary: basic aggregation', () async {
      await repo.saveEntries([
        ExpenseEntry(id: 'm1', amount: 10000, category: '住居費', date: DateTime(2026, 6, 1)),
        ExpenseEntry(id: 'm2', amount: 3000, category: '食費', date: DateTime(2026, 6, 15)),
        ExpenseEntry(id: 'm3', amount: 2000, category: '食費', date: DateTime(2026, 6, 30)),
      ]);

      final result = await service.getMonthlySummary(DateTime(2026, 6, 15));

      expect(result.period.type, 'monthly');
      expect(result.period.start, DateTime(2026, 6, 1));
      expect(result.period.end, DateTime(2026, 6, 30));
      expect(result.current.total, 15000);
      expect(result.current.byCategory.length, 2);
      expect(result.previousPeriod.start, DateTime(2026, 5, 1));
      expect(result.previousPeriod.end, DateTime(2026, 5, 31));
    });

    test('monthly summary: 31-day vs 30-day months', () async {
      // 1月（31日）
      await repo.saveEntry(
        ExpenseEntry(id: 'jan', amount: 1000, category: '食費', date: DateTime(2026, 1, 31)),
      );
      final janResult = await service.getMonthlySummary(DateTime(2026, 1, 15));
      expect(janResult.period.end, DateTime(2026, 1, 31));

      // 2月（28日、2026は平年）
      await repo.clearAll();
      await repo.saveEntry(
        ExpenseEntry(id: 'feb', amount: 1000, category: '食費', date: DateTime(2026, 2, 28)),
      );
      final febResult = await service.getMonthlySummary(DateTime(2026, 2, 15));
      expect(febResult.period.end, DateTime(2026, 2, 28));
    });

    test('monthly summary: year boundary (December → January)', () async {
      await repo.saveEntries([
        ExpenseEntry(id: 'dec', amount: 5000, category: '食費', date: DateTime(2025, 12, 20)),
        ExpenseEntry(id: 'jan', amount: 3000, category: '食費', date: DateTime(2026, 1, 10)),
      ]);

      // 2026年1月の集計
      final janResult = await service.getMonthlySummary(DateTime(2026, 1, 10));
      expect(janResult.current.total, 3000);
      expect(janResult.previous.total, 5000); // 前月=2025年12月
      expect(janResult.previousPeriod.start, DateTime(2025, 12, 1));
      expect(janResult.previousPeriod.end, DateTime(2025, 12, 31));
      expect(janResult.comparison.totalChange, -2000);
    });

    test('empty period returns zeros', () async {
      final result = await service.getWeeklySummary(DateTime(2026, 6, 18));

      expect(result.current.total, 0);
      expect(result.current.byCategory, isEmpty);
      expect(result.current.byDay, isEmpty);
      expect(result.previous.total, 0);
      expect(result.comparison.totalChange, 0);
      expect(result.comparison.totalChangePercent, 0.0);
    });

    test('single day with multiple categories', () async {
      await repo.saveEntries([
        ExpenseEntry(id: 'a', amount: 5000, category: '食費', date: DateTime(2026, 6, 22)),
        ExpenseEntry(id: 'b', amount: 3000, category: '交通費', date: DateTime(2026, 6, 22)),
        ExpenseEntry(id: 'c', amount: 2000, category: '娯楽', date: DateTime(2026, 6, 22)),
      ]);

      final result = await service.getWeeklySummary(DateTime(2026, 6, 22));

      expect(result.current.total, 10000);
      expect(result.current.byCategory.length, 3);
      expect(result.current.byDay.length, 1);
      expect(result.current.byDay[0].amount, 10000);
    });

    test('percentage decreases with previous comparison', () async {
      // 今週
      final thisMon = DateTime(2026, 6, 15);
      await _seedWeek(thisMon, [
        (category: '食費', amount: 2000, dayOffset: 1),
      ]);

      // 前週（多い）
      final prevMon = DateTime(2026, 6, 8);
      await _seedWeek(prevMon, [
        (category: '食費', amount: 5000, dayOffset: 1),
      ]);

      final result = await service.getWeeklySummary(DateTime(2026, 6, 18));
      expect(result.comparison.totalChange, -3000);
      expect(result.comparison.totalChangePercent, closeTo(-60.0, 0.1));
    });

    test('category comparison includes both periods\' categories', () async {
      // 今週: 食費のみ
      final thisMon = DateTime(2026, 6, 15);
      await _seedWeek(thisMon, [
        (category: '食費', amount: 3000, dayOffset: 0),
      ]);
      // 前週: 交通費のみ
      final prevMon = DateTime(2026, 6, 8);
      await _seedWeek(prevMon, [
        (category: '交通費', amount: 4000, dayOffset: 0),
      ]);

      final result = await service.getWeeklySummary(DateTime(2026, 6, 18));
      expect(result.comparison.byCategoryChanges.length, 2);
      expect(result.comparison.byCategoryChanges.any((c) => c.category == '食費'), true);
      expect(result.comparison.byCategoryChanges.any((c) => c.category == '交通費'), true);
    });

    test('category totals sorted by amount descending', () async {
      await repo.saveEntries([
        ExpenseEntry(id: '1', amount: 1000, category: '交通費', date: DateTime(2026, 6, 22)),
        ExpenseEntry(id: '2', amount: 5000, category: '食費', date: DateTime(2026, 6, 22)),
        ExpenseEntry(id: '3', amount: 2000, category: '娯楽', date: DateTime(2026, 6, 22)),
      ]);

      final result = await service.getWeeklySummary(DateTime(2026, 6, 22));
      expect(result.current.byCategory[0].category, '食費');
      expect(result.current.byCategory[1].category, '娯楽');
      expect(result.current.byCategory[2].category, '交通費');
    });
  });
}
