import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/domain/services/expense_aggregation_service.dart';
import 'package:kozuchi/domain/services/expense_repository_impl.dart';
import 'package:kozuchi/features/budget/data/closing_day_repository.dart';

DateTime day(int year, int month, int dayOfMonth) =>
    DateTime(year, month, dayOfMonth);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InMemoryClosingDayRepository', () {
    test('未保存なら既定値 1', () async {
      final repo = InMemoryClosingDayRepository();
      expect(await repo.load(), 1);
      expect(repo.stored, isNull);
    });

    test('save → load の往復', () async {
      final repo = InMemoryClosingDayRepository();
      await repo.save(25);
      expect(repo.stored, 25);
      expect(await repo.load(), 25);
    });

    test('save(99) は正規化されて 1 になる', () async {
      final repo = InMemoryClosingDayRepository();
      await repo.save(99);
      expect(repo.stored, 1);
      expect(await repo.load(), 1);
    });

    test('save(0) は正規化されて 1 になる', () async {
      final repo = InMemoryClosingDayRepository();
      await repo.save(0);
      expect(await repo.load(), 1);
    });

    test('外部から不正値が入っても load で正規化される', () async {
      final repo = InMemoryClosingDayRepository()..stored = 100;
      expect(await repo.load(), 1);
    });
  });

  group('SharedPreferencesClosingDayRepository', () {
    const repo = SharedPreferencesClosingDayRepository();

    test('storageKey は budget_closing_day_v1', () {
      expect(SharedPreferencesClosingDayRepository.storageKey,
          'budget_closing_day_v1');
    });

    test('未保存なら既定値 1', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await repo.load(), 1);
    });

    test('保存済み 25 を読み出す', () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesClosingDayRepository.storageKey: 25,
      });
      expect(await repo.load(), 25);
    });

    test('範囲外の保存値 99 は 1 にフォールバックする（例外を投げない）', () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesClosingDayRepository.storageKey: 99,
      });
      expect(await repo.load(), 1);
    });

    test('負の保存値は 1 にフォールバックする', () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesClosingDayRepository.storageKey: -2,
      });
      expect(await repo.load(), 1);
    });

    test('型破損（文字列）は 1 にフォールバックする', () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesClosingDayRepository.storageKey: 'abc',
      });
      expect(await repo.load(), 1);
    });

    test('save → load の往復（正規化込み）', () async {
      SharedPreferences.setMockInitialValues({});
      await repo.save(25);
      expect(await repo.load(), 25);

      await repo.save(99);
      expect(await repo.load(), 1);
    });
  });

  group('ExpenseAggregationService の締め日対応', () {
    late InMemoryExpenseRepository repo;
    late ExpenseAggregationService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      repo = InMemoryExpenseRepository();
      service = ExpenseAggregationService(repo);
      return repo.saveEntries([
        ExpenseEntry(
            id: 'p1', amount: 100, category: '食費', date: day(2026, 10, 25)),
        ExpenseEntry(
            id: 'c1', amount: 200, category: '食費', date: day(2026, 10, 26)),
        ExpenseEntry(
            id: 'c2', amount: 300, category: '交通費', date: day(2026, 11, 25)),
        ExpenseEntry(
            id: 'n1', amount: 400, category: '食費', date: day(2026, 11, 26)),
      ]);
    });

    test('既定（closingDay=1）は暦月のまま', () async {
      final result = await service.getMonthlySummary(day(2026, 11, 10));
      expect(result.period.start, day(2026, 11, 1));
      expect(result.period.end, day(2026, 11, 30));
      // 11/25 の 300 + 11/26 の 400（いずれも暦月11月に属する）
      expect(result.current.total, 700);
      expect(result.previousPeriod.start, day(2026, 10, 1));
      expect(result.previousPeriod.end, day(2026, 10, 31));
      // 前期間（10月: 10/25 の 100 + 10/26 の 200）
      expect(result.previous.total, 300);
    });

    test('closingDay=25 は 10/26〜11/25 のエントリだけ集計する', () async {
      final result = await service.getMonthlySummary(
        day(2026, 11, 10),
        closingDay: 25,
      );
      expect(result.period.start, day(2026, 10, 26));
      expect(result.period.end, day(2026, 11, 25));
      // 10/26 の 200 + 11/25 の 300。10/25 と 11/26 は期間外。
      expect(result.current.total, 500);
      expect(result.previousPeriod.start, day(2026, 9, 26));
      expect(result.previousPeriod.end, day(2026, 10, 25));
      expect(result.previous.total, 100);
    });

    test('closingDay=25 で締め日翌日の参照は次期間になる', () async {
      final result = await service.getMonthlySummary(
        day(2026, 11, 26),
        closingDay: 25,
      );
      expect(result.period.start, day(2026, 11, 26));
      expect(result.period.end, day(2026, 12, 25));
      expect(result.current.total, 400);
    });
  });
}
