import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/domain/services/expense_repository_impl.dart';
import 'package:kozuchi/features/tags/data/tag_repository.dart';
import 'package:kozuchi/features/tags/domain/models/tagged_transaction.dart';
import 'package:kozuchi/features/transaction_history/presentation/state/transaction_controller.dart';

/// 親探針（イシコリドメ）: 取引削除とタグ紐付けの合成不変条件。
///
/// 眷属の試練は「削除→紐付けが消える」「Undo で戻る」を個別に撃つが、
/// ここでは **失敗側の対照**（消せない取引でタグを消さない）・
/// **タグ定義を巻き込まない**・**バックアップの取り違え**を撃つ。
TransactionModel _tx({
  String? id,
  int amount = -100,
  String purpose = 'ランチ',
  String category = '食費',
  String datetime = '2026-10-01T12:00:00.000',
}) =>
    TransactionModel(
      amount: amount,
      purpose: purpose,
      category: category,
      datetime: datetime,
      id: id,
    );

Future<InMemoryExpenseRepository> _seed(String id) async {
  final repo = InMemoryExpenseRepository();
  await repo.saveEntry(
    ExpenseEntry(
      id: id,
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

  test('① 削除できない取引（id 無し＝ローカル取引）ではタグを消さない', () async {
    final tx = _tx(id: null);
    final key = TaggedTransaction.keyOfTransaction(tx);
    await tagRepository.assignTags(key, const ['t1']);

    final controller = TransactionController(
      expenseRepository: InMemoryExpenseRepository(),
      tagRepository: tagRepository,
    );
    expect(await controller.deleteTransaction(tx), isFalse);
    // 取引が残っているのにタグだけ消える事故を禁ずる
    expect(await tagRepository.tagsFor(key), ['t1']);
    controller.dispose();
  });

  test('② 削除してもタグ定義そのものは消えない（紐付けだけを掃除する）', () async {
    final repo = await _seed('a');
    final tx = _tx(id: 'a');
    final key = TaggedTransaction.keyOfTransaction(tx);
    final tags = await tagRepository.createTag('外食', id: 't1');
    expect(tags.single.id, 't1');
    await tagRepository.assignTags(key, const ['t1']);

    final controller = TransactionController(
      expenseRepository: repo,
      tagRepository: tagRepository,
    );
    expect(await controller.deleteTransaction(tx), isTrue);

    expect(await tagRepository.tagsFor(key), isEmpty);
    expect((await tagRepository.loadTags()).map((t) => t.id), ['t1']);
    controller.dispose();
  });

  test('③ 削除→孤児刈り取りで他取引の紐付けは生き残る', () async {
    final repo = await _seed('a');
    await repo.saveEntry(
      ExpenseEntry(
        id: 'b',
        amount: 300,
        category: '娯楽',
        date: DateTime(2026, 10, 2, 19),
        note: '映画',
      ),
    );
    final target = _tx(id: 'a');
    final keeper = _tx(
      id: 'b',
      amount: -300,
      purpose: '映画',
      category: '娯楽',
      datetime: '2026-10-02T19:00:00.000',
    );
    final targetKey = TaggedTransaction.keyOfTransaction(target);
    final keeperKey = TaggedTransaction.keyOfTransaction(keeper);
    await tagRepository.assignTags(targetKey, const ['t1']);
    await tagRepository.assignTags(keeperKey, const ['t2']);

    final controller = TransactionController(
      expenseRepository: repo,
      tagRepository: tagRepository,
    );
    expect(await controller.deleteTransaction(target), isTrue);

    // 全期間キー（存命の取引のみ）で刈り取ると孤児は 0 件
    final known = controller.transactions
        .map(TaggedTransaction.keyOfTransaction)
        .toList();
    expect(known, contains(keeperKey));
    expect(await tagRepository.pruneOrphans(known), 0);
    expect(await tagRepository.tagsFor(keeperKey), ['t2']);
    controller.dispose();
  });

  test('④ 退避は直前1件のみ — 別取引のタグを復元時に取り違えない', () async {
    final repo = await _seed('a');
    await repo.saveEntry(
      ExpenseEntry(
        id: 'b',
        amount: 300,
        category: '娯楽',
        date: DateTime(2026, 10, 2, 19),
        note: '映画',
      ),
    );
    final txA = _tx(id: 'a');
    final txB = _tx(
      id: 'b',
      amount: -300,
      purpose: '映画',
      category: '娯楽',
      datetime: '2026-10-02T19:00:00.000',
    );
    final keyA = TaggedTransaction.keyOfTransaction(txA);
    final keyB = TaggedTransaction.keyOfTransaction(txB);
    await tagRepository.assignTags(keyA, const ['tA']);
    await tagRepository.assignTags(keyB, const ['tB']);

    final controller = TransactionController(
      expenseRepository: repo,
      tagRepository: tagRepository,
    );
    // A を削除 → 復元（A のタグが戻る）
    expect(await controller.deleteTransaction(txA), isTrue);
    expect(await controller.restoreTransaction(txA), isTrue);
    expect(await tagRepository.tagsFor(keyA), ['tA']);

    // B を削除した後、A を復元しても B のタグが A に付かない
    expect(await controller.deleteTransaction(txB), isTrue);
    expect(await controller.restoreTransaction(txA), isTrue);
    expect(await tagRepository.tagsFor(keyA), ['tA']);
    expect(await tagRepository.tagsFor(keyB), isEmpty);
    controller.dispose();
  });

  test('⑤ 同じ内容から作った別インスタンスは同じキーになる（掃除が効く前提）', () {
    final a = _tx(id: 'x');
    final b = _tx(id: 'y');
    expect(
      TaggedTransaction.keyOfTransaction(a),
      TaggedTransaction.keyOfTransaction(b),
    );
    expect(
      TaggedTransaction.keyOfTransaction(a),
      isNot(TaggedTransaction.keyOfTransaction(_tx(id: 'x', amount: -101))),
    );
  });
}
