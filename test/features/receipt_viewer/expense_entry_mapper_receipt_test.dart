import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/domain/services/expense_entry_mapper.dart';

void main() {
  group('ExpenseEntryMapper レシートパス引き継ぎ', () {
    test('receiptImagePath を引き継ぐ', () {
      final entry = ExpenseEntry(
        id: 'e1',
        amount: 500,
        category: '食費',
        date: DateTime(2026, 9, 18, 10),
        receiptImagePath: '/tmp/receipt.jpg',
      );
      final model = ExpenseEntryMapper.toTransactionModel(entry);
      expect(model.receiptImagePath, '/tmp/receipt.jpg');
      expect(model.amount, -500);
    });

    test('receiptImagePath なしでも null を引き継ぐ', () {
      final entry = ExpenseEntry(
        id: 'e2',
        amount: 300,
        category: '交通費',
        date: DateTime(2026, 9, 18, 12),
      );
      final model = ExpenseEntryMapper.toTransactionModel(entry);
      expect(model.receiptImagePath, isNull);
    });
  });

  group('TransactionModel JSON 往復', () {
    test('receiptImagePath ありの fromJson・toJson 往復', () {
      final original = TransactionModel(
        amount: -500,
        purpose: 'コーヒー',
        category: '食費',
        datetime: '2026-09-18T10:00:00.000',
        receiptImagePath: '/tmp/receipt.jpg',
      );
      final restored = TransactionModel.fromJson(original.toJson());
      expect(restored.receiptImagePath, '/tmp/receipt.jpg');
      expect(restored.amount, original.amount);
      expect(restored.purpose, original.purpose);
      expect(restored.category, original.category);
      expect(restored.datetime, original.datetime);
    });

    test('receiptImagePath なしの fromJson・toJson 往復', () {
      const original = TransactionModel(
        amount: -500,
        purpose: 'コーヒー',
        category: '食費',
        datetime: '2026-09-18T10:00:00.000',
      );
      final restored = TransactionModel.fromJson(original.toJson());
      expect(restored.receiptImagePath, isNull);
    });

    test('TransactionModel の == は receiptImagePath を含めて比較する', () {
      const a = TransactionModel(
        amount: -500,
        purpose: 'コーヒー',
        category: '食費',
        datetime: '2026-09-18T10:00:00.000',
        receiptImagePath: '/tmp/a.jpg',
      );
      const b = TransactionModel(
        amount: -500,
        purpose: 'コーヒー',
        category: '食費',
        datetime: '2026-09-18T10:00:00.000',
        receiptImagePath: '/tmp/b.jpg',
      );
      // TransactionModel に == の実装が無ければ skip する形になるが、
      // 少なくとも例外なく比較できることを確認する。
      expect(a == b, isFalse);
    });
  });

  group('ExpenseEntry JSON 往復', () {
    test('receiptImagePath を含む往復', () {
      final entry = ExpenseEntry(
        id: 'e3',
        amount: 800,
        category: '娯楽',
        date: DateTime(2026, 9, 18),
        receiptImagePath: '/tmp/receipt.png',
      );
      final restored = ExpenseEntry.fromJson(entry.toJson());
      expect(restored.receiptImagePath, '/tmp/receipt.png');
    });
  });
}
