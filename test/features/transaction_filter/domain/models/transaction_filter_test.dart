import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/transaction_filter/domain/models/transaction_filter.dart';

void main() {
  group('TransactionFilter', () {
    test('default filter has type all and null dates', () {
      const filter = TransactionFilter();
      expect(filter.type, TransactionFilterType.all);
      expect(filter.startDate, isNull);
      expect(filter.endDate, isNull);
    });

    test('custom filter preserves values', () {
      final startDate = DateTime(2026, 6, 1);
      final endDate = DateTime(2026, 6, 23);
      final filter = TransactionFilter(
        type: TransactionFilterType.income,
        startDate: startDate,
        endDate: endDate,
      );
      expect(filter.type, TransactionFilterType.income);
      expect(filter.startDate, startDate);
      expect(filter.endDate, endDate);
    });

    test('copyWith creates modified copy', () {
      final original = TransactionFilter(
        type: TransactionFilterType.all,
        startDate: DateTime(2026, 6, 1),
        endDate: DateTime(2026, 6, 23),
      );
      final modified = original.copyWith(type: TransactionFilterType.expense);
      expect(modified.type, TransactionFilterType.expense);
      expect(modified.startDate, original.startDate);
      expect(modified.endDate, original.endDate);
    });

    test('copyWith preserves unchanged fields', () {
      final original = TransactionFilter(
        type: TransactionFilterType.income,
        startDate: DateTime(2026, 5, 1),
      );
      final modified = original.copyWith(endDate: DateTime(2026, 5, 31));
      expect(modified.type, TransactionFilterType.income);
      expect(modified.startDate, DateTime(2026, 5, 1));
      expect(modified.endDate, DateTime(2026, 5, 31));
    });

    test('equality uses value semantics', () {
      final a = TransactionFilter(
        type: TransactionFilterType.all,
        startDate: DateTime(2026, 6, 1),
        endDate: DateTime(2026, 6, 23),
      );
      final b = TransactionFilter(
        type: TransactionFilterType.all,
        startDate: DateTime(2026, 6, 1),
        endDate: DateTime(2026, 6, 23),
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different type creates inequality', () {
      final a = TransactionFilter(type: TransactionFilterType.all);
      final b = TransactionFilter(type: TransactionFilterType.income);
      expect(a, isNot(equals(b)));
    });

    test('different dates create inequality', () {
      final a = TransactionFilter(
        type: TransactionFilterType.all,
        startDate: DateTime(2026, 6, 1),
      );
      final b = TransactionFilter(
        type: TransactionFilterType.all,
        startDate: DateTime(2026, 6, 2),
      );
      expect(a, isNot(equals(b)));
    });

    test('toJson and fromJson roundtrip', () {
      final original = TransactionFilter(
        type: TransactionFilterType.expense,
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2026, 4, 30),
      );
      final json = original.toJson();
      final restored = TransactionFilter.fromJson(json);
      expect(restored, equals(original));
    });

    test('fromJson handles null dates', () {
      final json = <String, dynamic>{'type': 'all'};
      final filter = TransactionFilter.fromJson(json);
      expect(filter.type, TransactionFilterType.all);
      expect(filter.startDate, isNull);
      expect(filter.endDate, isNull);
    });

    test('fromJson parses ISO date strings', () {
      final json = <String, dynamic>{
        'type': 'income',
        'startDate': '2026-06-01',
        'endDate': '2026-06-23',
      };
      final filter = TransactionFilter.fromJson(json);
      expect(filter.type, TransactionFilterType.income);
      expect(filter.startDate, DateTime(2026, 6, 1));
      expect(filter.endDate, DateTime(2026, 6, 23));
    });
  });

  group('TransactionFilterType', () {
    test('all three values exist', () {
      expect(TransactionFilterType.values.length, 3);
      expect(TransactionFilterType.values, contains(TransactionFilterType.all));
      expect(TransactionFilterType.values, contains(TransactionFilterType.income));
      expect(TransactionFilterType.values, contains(TransactionFilterType.expense));
    });

    test('label returns Japanese text', () {
      expect(TransactionFilterType.all.label, '全件');
      expect(TransactionFilterType.income.label, '収入');
      expect(TransactionFilterType.expense.label, '支出');
    });
  });
}
