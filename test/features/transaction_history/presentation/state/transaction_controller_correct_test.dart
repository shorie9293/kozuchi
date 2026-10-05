import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/domain/services/expense_repository_impl.dart';
import 'package:kozuchi/features/transaction_history/presentation/state/transaction_controller.dart';

TransactionModel _tx(String id, int amount, String datetime) =>
    TransactionModel(
      amount: amount,
      purpose: 'メモ$id',
      category: '食費',
      datetime: datetime,
      id: id,
    );

void main() {
  group('TransactionController.deleteTransaction', () {
    test('支出明細由来の取引を削除し、一覧を再取得する', () async {
      final repo = InMemoryExpenseRepository();
      await repo.saveEntries([
        ExpenseEntry(
          id: 'a',
          amount: 100,
          category: '食費',
          date: DateTime(2026, 10, 1),
        ),
        ExpenseEntry(
          id: 'b',
          amount: 200,
          category: '交通費',
          date: DateTime(2026, 10, 2),
        ),
      ]);
      final controller = TransactionController(expenseRepository: repo);
      await controller.fetchTransactions();
      expect(controller.transactions.length, 2);

      final ok =
          await controller.deleteTransaction(_tx('a', -100, '2026-10-01T12:00:00.000'));
      expect(ok, isTrue);
      expect(controller.transactions.single.id, 'b');
      expect(await repo.getEntryCount(), 1);
      controller.dispose();
    });

    test('id 無しの取引（ローカル/旧API由来）は訂正不能で false', () async {
      final repo = InMemoryExpenseRepository();
      final controller = TransactionController(expenseRepository: repo);
      final noId = TransactionModel(
        amount: -100,
        purpose: 'CSV取引',
        category: '食費',
        datetime: '2026-10-01T12:00:00.000',
      );
      expect(await controller.deleteTransaction(noId), isFalse);
      expect(await controller.updateTransaction(noId), isFalse);
      controller.dispose();
    });

    test('リポジトリ未設定なら false', () async {
      final controller = TransactionController();
      expect(
        await controller.deleteTransaction(
          _tx('a', -100, '2026-10-01T12:00:00.000'),
        ),
        isFalse,
      );
      controller.dispose();
    });

    test('存在しないIDの削除は冪等で true（一覧は変わらない）', () async {
      final repo = InMemoryExpenseRepository();
      await repo.saveEntry(
        ExpenseEntry(
          id: 'a',
          amount: 100,
          category: '食費',
          date: DateTime(2026, 10, 1),
        ),
      );
      final controller = TransactionController(expenseRepository: repo);
      expect(
        await controller.deleteTransaction(
          _tx('zzz', -100, '2026-10-01T12:00:00.000'),
        ),
        isTrue,
      );
      expect(controller.transactions.single.id, 'a');
      controller.dispose();
    });
  });

  group('TransactionController.updateTransaction', () {
    test('編集が永続化に到達し、再取得後の一覧に反映される', () async {
      final repo = InMemoryExpenseRepository();
      await repo.saveEntry(
        ExpenseEntry(
          id: 'a',
          amount: 500,
          category: '食費',
          date: DateTime(2026, 10, 1, 12, 0),
          note: '昼食',
          receiptImagePath: '/r.jpg',
        ),
      );
      final controller = TransactionController(expenseRepository: repo);
      await controller.fetchTransactions();

      final ok = await controller.updateTransaction(
        _tx('a', -1200, '2026-10-03T09:00:00.000')
            .copyWith(purpose: '夜食', category: '外食'),
      );
      expect(ok, isTrue);

      final updated = await repo.getEntryById('a');
      expect(updated!.amount, 1200);
      expect(updated.category, '外食');
      expect(updated.note, '夜食');
      expect(updated.date, DateTime(2026, 10, 3, 9, 0));
      // 編集対象外フィールドの保持
      expect(updated.receiptImagePath, '/r.jpg');

      expect(controller.transactions.single.amount, -1200);
      expect(controller.transactions.single.category, '外食');
      controller.dispose();
    });

    test('メモがカテゴリと同一なら note は null に寄る', () async {
      final repo = InMemoryExpenseRepository();
      await repo.saveEntry(
        ExpenseEntry(
          id: 'a',
          amount: 500,
          category: '食費',
          date: DateTime(2026, 10, 1),
          note: '昼食',
        ),
      );
      final controller = TransactionController(expenseRepository: repo);
      await controller.updateTransaction(
        _tx('a', -700, '2026-10-01T12:00:00.000').copyWith(
          purpose: '食費',
          category: '食費',
        ),
      );
      expect((await repo.getEntryById('a'))!.note, isNull);
      controller.dispose();
    });

    test('収入（正値）の取引は支出明細ではないため訂正不能で false', () async {
      final repo = InMemoryExpenseRepository();
      final controller = TransactionController(expenseRepository: repo);
      expect(
        await controller.updateTransaction(
          TransactionModel(
            amount: 1000,
            purpose: '収入',
            category: 'その他',
            datetime: '2026-10-01T12:00:00.000',
            id: 'a',
          ),
        ),
        isFalse,
      );
      controller.dispose();
    });
  });
}
