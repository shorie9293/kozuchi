import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/domain/services/expense_repository_impl.dart';
import 'package:kozuchi/features/tags/data/tag_repository.dart';
import 'package:kozuchi/features/tags/domain/models/tagged_transaction.dart';
import 'package:kozuchi/features/transaction_history/presentation/state/transaction_controller.dart';

const _datetime = '2026-10-01T12:00:00.000';

TransactionModel _tx({String id = 'a', int amount = -100}) => TransactionModel(
      amount: amount,
      purpose: 'ランチ',
      category: '食費',
      datetime: _datetime,
      id: id,
    );

Future<InMemoryExpenseRepository> _seedRepo() async {
  final repo = InMemoryExpenseRepository();
  await repo.saveEntry(
    ExpenseEntry(
      id: 'a',
      amount: 100,
      category: '食費',
      date: DateTime(2026, 10, 1, 12),
      note: 'ランチ',
    ),
  );
  return repo;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const tagRepository = TagRepository();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TransactionController 削除時のタグ紐付け掃除', () {
    test('削除するとタグ紐付けも消える（removeKeys 到達）', () async {
      final repo = await _seedRepo();
      final tx = _tx();
      final key = TaggedTransaction.keyOfTransaction(tx);
      await tagRepository.assignTags(key, const ['t1', 't2']);

      final controller = TransactionController(
        expenseRepository: repo,
        tagRepository: tagRepository,
      );
      expect(await controller.deleteTransaction(tx), isTrue);

      expect(await tagRepository.tagsFor(key), isEmpty);
      controller.dispose();
    });

    test('削除→Undo 復元でタグが元通りになる', () async {
      final repo = await _seedRepo();
      final tx = _tx();
      final key = TaggedTransaction.keyOfTransaction(tx);
      await tagRepository.assignTags(key, const ['t1', 't2']);

      final controller = TransactionController(
        expenseRepository: repo,
        tagRepository: tagRepository,
      );
      expect(await controller.deleteTransaction(tx), isTrue);
      expect(await tagRepository.tagsFor(key), isEmpty);

      expect(await controller.restoreTransaction(tx), isTrue);

      expect(await tagRepository.tagsFor(key), ['t1', 't2']);
      expect(controller.transactions.single.id, 'a');
      controller.dispose();
    });

    test('削除後に同じ内容の取引を再登録しても古いタグは復活しない', () async {
      final repo = await _seedRepo();
      final tx = _tx();
      final key = TaggedTransaction.keyOfTransaction(tx);
      await tagRepository.assignTags(key, const ['t1']);

      final controller = TransactionController(
        expenseRepository: repo,
        tagRepository: tagRepository,
      );
      expect(await controller.deleteTransaction(tx), isTrue);

      // 同じ日時・金額・用途・カテゴリ（＝同一キー）で別IDの取引を再登録
      await repo.saveEntry(
        ExpenseEntry(
          id: 'b',
          amount: 100,
          category: '食費',
          date: DateTime(2026, 10, 1, 12),
          note: 'ランチ',
        ),
      );
      await controller.fetchTransactions();

      expect(controller.transactions.length, 1);
      expect(await tagRepository.tagsFor(key), isEmpty);
      controller.dispose();
    });

    test('tagRepository 未指定なら従来通りタグに触れない', () async {
      final repo = await _seedRepo();
      final tx = _tx();
      final key = TaggedTransaction.keyOfTransaction(tx);
      await tagRepository.assignTags(key, const ['t1']);

      final controller = TransactionController(expenseRepository: repo);
      expect(await controller.deleteTransaction(tx), isTrue);

      // 従来挙動（タグ掃除なし）を維持
      expect(await tagRepository.tagsFor(key), ['t1']);
      controller.dispose();
    });

    test('削除失敗時はタグ紐付けを消さない', () async {
      final repo = InMemoryExpenseRepository();
      final tx = _tx();
      final key = TaggedTransaction.keyOfTransaction(tx);
      await tagRepository.assignTags(key, const ['t1']);

      // InMemory 実装は存在しないIDの削除を成功扱いにするため、
      // id 無し（訂正不能）経路でタグ非破壊を確認する。
      final controller = TransactionController(
        expenseRepository: repo,
        tagRepository: tagRepository,
      );
      final noId = TransactionModel(
        amount: -100,
        purpose: 'ランチ',
        category: '食費',
        datetime: _datetime,
      );
      expect(await controller.deleteTransaction(noId), isFalse);
      expect(await tagRepository.tagsFor(key), ['t1']);
      controller.dispose();
    });
  });
}
