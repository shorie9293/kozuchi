import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/domain/services/expense_repository_impl.dart';
import 'package:kozuchi/features/csv_import/data/local_transaction_repository.dart';
import 'package:kozuchi/features/transaction_filter/domain/models/transaction_filter.dart';
import 'package:kozuchi/features/transaction_history/presentation/state/transaction_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TransactionController 支出明細（expense_entries）統合', () {
    test('expenseRepository指定時は支出明細がTransactionModelとして統合される', () async {
      final repo = InMemoryExpenseRepository();
      await repo.saveEntries([
        ExpenseEntry(
          id: 'e1',
          amount: 3000,
          category: '食費',
          date: DateTime(2026, 6, 24, 8, 30),
          note: 'ランチ',
        ),
      ]);

      final controller = TransactionController(
        expenseRepository: repo,
        initialFilter: TransactionFilter(
          type: TransactionFilterType.all,
          startDate: DateTime(2026, 6, 1),
          endDate: DateTime(2026, 6, 30),
        ),
      );

      await controller.fetchTransactions();

      expect(controller.transactions, hasLength(1));
      expect(controller.transactions[0].amount, -3000);
      expect(controller.transactions[0].purpose, 'ランチ');
      expect(controller.transactions[0].category, '食費');
      expect(controller.error, isNull);
    });

    test('支出フィルタでは支出明細が表示される', () async {
      final repo = InMemoryExpenseRepository();
      await repo.saveEntry(ExpenseEntry(
        id: 'e1',
        amount: 500,
        category: 'その他',
        date: DateTime(2026, 6, 10),
      ));

      final controller = TransactionController(
        expenseRepository: repo,
        initialFilter: TransactionFilter(
          type: TransactionFilterType.expense,
        ),
      );

      await controller.fetchTransactions();
      expect(controller.transactions, hasLength(1));
    });

    test('収入フィルタでは支出明細は表示されない', () async {
      final repo = InMemoryExpenseRepository();
      await repo.saveEntry(ExpenseEntry(
        id: 'e1',
        amount: 500,
        category: 'その他',
        date: DateTime(2026, 6, 10),
      ));

      final controller = TransactionController(
        expenseRepository: repo,
        initialFilter: const TransactionFilter(
          type: TransactionFilterType.income,
        ),
      );

      await controller.fetchTransactions();
      expect(controller.transactions, isEmpty);
    });

    test('日付範囲外の支出明細は表示されない', () async {
      final repo = InMemoryExpenseRepository();
      await repo.saveEntry(ExpenseEntry(
        id: 'e1',
        amount: 500,
        category: 'その他',
        date: DateTime(2026, 7, 10),
      ));

      final controller = TransactionController(
        expenseRepository: repo,
        initialFilter: TransactionFilter(
          type: TransactionFilterType.all,
          startDate: DateTime(2026, 6, 1),
          endDate: DateTime(2026, 6, 30),
        ),
      );

      await controller.fetchTransactions();
      expect(controller.transactions, isEmpty);
    });

    test('expenseRepositoryとlocalRepositoryの両方がある場合は両方が統合される', () async {
      final repo = InMemoryExpenseRepository();
      await repo.saveEntry(ExpenseEntry(
        id: 'e1',
        amount: 1000,
        category: '食費',
        date: DateTime(2026, 6, 20, 10),
        note: '明細',
      ));

      final localRepo = const LocalTransactionRepository();
      await localRepo.addTransactions([
        TransactionModel(
          amount: -450,
          purpose: 'ローカル取引',
          category: 'その他',
          datetime: '2026-06-12T10:00:00',
        ),
      ]);

      final controller = TransactionController(
        expenseRepository: repo,
        localRepository: localRepo,
      );

      await controller.fetchTransactions();

      final purposes = controller.transactions.map((t) => t.purpose).toSet();
      expect(purposes, contains('明細'));
      expect(purposes, contains('ローカル取引'));
    });
  });
}
