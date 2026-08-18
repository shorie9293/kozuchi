import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/domain/services/expense_entry_mapper.dart';

void main() {
  group('ExpenseEntryMapper', () {
    test('ExpenseEntryを支出(負)のTransactionModelに変換する', () {
      final entry = ExpenseEntry(
        id: 'id-1',
        amount: 3000,
        category: '食費',
        date: DateTime.parse('2026-06-24T08:30:00.000'),
        note: 'ランチ',
      );

      final tx = ExpenseEntryMapper.toTransactionModel(entry);

      expect(tx.amount, -3000);
      expect(tx.category, '食費');
      expect(tx.purpose, 'ランチ');
      expect(tx.isIncome, isFalse);
      expect(tx.absAmount, 3000);
      expect(tx.datetime, '2026-06-24T08:30:00.000');
    });

    test('noteがnullの場合はpurposeにカテゴリ名を使う', () {
      final entry = ExpenseEntry(
        id: 'id-2',
        amount: 1500,
        category: '交通',
        date: DateTime.parse('2026-06-25T09:00:00.000'),
      );

      final tx = ExpenseEntryMapper.toTransactionModel(entry);

      expect(tx.purpose, '交通');
      expect(tx.amount, -1500);
    });

    test('全エントリをTransactionModelのリストへ一括変換する', () {
      final entries = [
        ExpenseEntry(
          id: 'id-3',
          amount: 100,
          category: 'その他',
          date: DateTime.parse('2026-06-26T10:00:00.000'),
          note: 'a',
        ),
        ExpenseEntry(
          id: 'id-4',
          amount: 200,
          category: '娯楽',
          date: DateTime.parse('2026-06-27T11:00:00.000'),
          note: 'b',
        ),
      ];

      final txs = ExpenseEntryMapper.toTransactionModels(entries);

      expect(txs, hasLength(2));
      expect(txs.first, isA<TransactionModel>());
    });
  });
}
