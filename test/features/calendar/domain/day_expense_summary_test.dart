import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/features/calendar/domain/day_expense_summary.dart';

ExpenseEntry entry(String id, int amount, DateTime date) => ExpenseEntry(
      id: id,
      amount: amount,
      category: '食費',
      date: date,
    );

void main() {
  final day = DateTime(2026, 9, 15);

  group('DayExpenseSummary 正規化と検証', () {
    test('date が 00:00:00 に正規化される', () {
      final summary = DayExpenseSummary(
        date: DateTime(2026, 9, 15, 10, 30),
        totalAmount: 0,
        entries: const [],
      );
      expect(summary.date, DateTime(2026, 9, 15));
      expect(summary.date.hour, 0);
      expect(summary.date.minute, 0);
    });

    test('totalAmount が負なら ArgumentError', () {
      expect(
        () => DayExpenseSummary(date: day, totalAmount: -1, entries: const []),
        throwsArgumentError,
      );
    });

    test('entries 合計と totalAmount 不一致なら ArgumentError', () {
      expect(
        () => DayExpenseSummary(
          date: day,
          totalAmount: 100,
          entries: [entry('a', 300, day)],
        ),
        throwsArgumentError,
      );
    });

    test('entries 内の日付が別日なら ArgumentError', () {
      expect(
        () => DayExpenseSummary(
          date: day,
          totalAmount: 300,
          entries: [entry('a', 300, DateTime(2026, 9, 16))],
        ),
        throwsArgumentError,
      );
    });

    test('entries が date と同日で時刻付きでも妥当（合計一致）', () {
      final summary = DayExpenseSummary(
        date: day,
        totalAmount: 700,
        entries: [
          entry('b', 400, DateTime(2026, 9, 15, 12, 0)),
          entry('a', 300, DateTime(2026, 9, 15, 9, 0)),
        ],
      );
      // date昇順→同時刻はid昇順でソートされる
      expect(summary.entries.map((e) => e.id).toList(), ['a', 'b']);
    });

    test('同時刻の entries は id 昇順でソート・入力は非破壊', () {
      final input = [
        entry('c', 100, day),
        entry('a', 100, day),
        entry('b', 100, day),
      ];
      final copy = List.of(input);
      final summary = DayExpenseSummary(
        date: day,
        totalAmount: 300,
        entries: input,
      );
      expect(summary.entries.map((e) => e.id).toList(), ['a', 'b', 'c']);
      expect(input.map((e) => e.id).toList(), copy.map((e) => e.id).toList());
    });
  });

  group('DayExpenseSummary アクセサ', () {
    test('entryCount / isEmpty', () {
      final empty = DayExpenseSummary(date: day, totalAmount: 0, entries: const []);
      expect(empty.entryCount, 0);
      expect(empty.isEmpty, isTrue);

      final full = DayExpenseSummary(
        date: day,
        totalAmount: 500,
        entries: [entry('a', 500, day)],
      );
      expect(full.entryCount, 1);
      expect(full.isEmpty, isFalse);
    });

    test('amountLabel が 0 なら空文字、それ以外は ¥ と3桁カンマ', () {
      expect(
        DayExpenseSummary(date: day, totalAmount: 0, entries: const []).amountLabel,
        '',
      );
      expect(
        DayExpenseSummary(
          date: day,
          totalAmount: 1234,
          entries: [entry('a', 1234, day)],
        ).amountLabel,
        '¥1,234',
      );
      expect(
        DayExpenseSummary(
          date: day,
          totalAmount: 1234567,
          entries: [entry('a', 1234567, day)],
        ).amountLabel,
        '¥1,234,567',
      );
    });
  });

  group('DayExpenseSummary 等価性', () {
    test('== と hashCode は date のみで比較', () {
      final a = DayExpenseSummary(date: day, totalAmount: 0, entries: const []);
      final b = DayExpenseSummary(
        date: day,
        totalAmount: 900,
        entries: [entry('a', 900, day)],
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);

      final other = DayExpenseSummary(
        date: DateTime(2026, 9, 16),
        totalAmount: 0,
        entries: const [],
      );
      expect(a == other, isFalse);
    });
  });
}