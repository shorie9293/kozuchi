import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/csv_import/data/local_transaction_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalTransactionRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = const LocalTransactionRepository();
  });

  TransactionModel makeTx({
    int amount = -100,
    String purpose = 'テスト取引',
    String category = 'その他',
    String datetime = '2026-06-01T12:00:00',
  }) {
    return TransactionModel(
      amount: amount,
      purpose: purpose,
      category: category,
      datetime: datetime,
    );
  }

  group('LocalTransactionRepository', () {
    test('未保存時は空リストを返す', () async {
      final loaded = await repository.loadAll();
      expect(loaded, isEmpty);
    });

    test('saveAll → loadAll 往復で同一の取引一覧が復元される', () async {
      final transactions = [
        makeTx(amount: 300000, purpose: '給与', category: '収入'),
        makeTx(amount: -450, purpose: 'コーヒー', category: '食費'),
      ];
      await repository.saveAll(transactions);

      final loaded = await repository.loadAll();
      expect(loaded, hasLength(2));
      expect(loaded[0].amount, 300000);
      expect(loaded[0].purpose, '給与');
      expect(loaded[1].amount, -450);
    });

    test('addTransactions で追加すると既存に追記される', () async {
      await repository.addTransactions([makeTx(amount: 100, purpose: '既存')]);

      final updated = await repository.addTransactions([
        makeTx(amount: -50, purpose: '追加'),
      ]);

      expect(updated, hasLength(2));
      final loaded = await repository.loadAll();
      expect(loaded, hasLength(2));
    });

    test('clear で全取引が削除される', () async {
      await repository.addTransactions([makeTx()]);
      expect(await repository.loadAll(), hasLength(1));

      await repository.clear();
      expect(await repository.loadAll(), isEmpty);
    });

    test('破損JSONは空リストとして扱われる', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('kozuchi_local_transactions', '破損データ{{{');

      final loaded = await repository.loadAll();
      expect(loaded, isEmpty);
    });
  });
}
