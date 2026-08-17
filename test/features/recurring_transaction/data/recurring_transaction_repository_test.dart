import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/features/recurring_transaction/data/recurring_transaction_repository.dart';
import 'package:kozuchi/features/recurring_transaction/domain/recurring_transaction.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecurringTransactionRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = const RecurringTransactionRepository();
  });

  RecurringTransaction makeDef({
    String id = 'rent',
    int amount = -85000,
    RecurringFrequency frequency = RecurringFrequency.monthly,
  }) {
    return RecurringTransaction(
      id: id,
      purpose: '家賃',
      category: '住居費',
      amount: amount,
      frequency: frequency,
      dayOfMonth: 5,
      startDate: DateTime(2026, 1, 5),
    );
  }

  group('RecurringTransactionRepository', () {
    test('未保存時は空リストを返す', () async {
      expect(await repository.loadDefinitions(), isEmpty);
    });

    test('addDefinition → loadDefinitions 往復で復元される', () async {
      await repository.addDefinition(makeDef());

      final defs = await repository.loadDefinitions();
      expect(defs, hasLength(1));
      expect(defs[0].id, 'rent');
      expect(defs[0].amount, -85000);
      expect(defs[0].frequency, RecurringFrequency.monthly);
    });

    test('removeDefinition で削除できる', () async {
      await repository.addDefinition(makeDef());
      await repository.addDefinition(makeDef(id: 'other'));

      await repository.removeDefinition('rent');

      final defs = await repository.loadDefinitions();
      expect(defs, hasLength(1));
      expect(defs[0].id, 'other');
    });

    test('saveDefinitions で一括保存できる', () async {
      await repository.saveDefinitions([
        makeDef(),
        makeDef(id: 'b', amount: -2000),
      ]);
      final defs = await repository.loadDefinitions();
      expect(defs, hasLength(2));
    });

    test('lastGenerated が未設定なら null を返す', () async {
      expect(await repository.loadLastGenerated('rent'), isNull);
    });

    test('saveLastGenerated → loadLastGenerated 往復で復元される', () async {
      final ts = DateTime(2026, 6, 10, 12, 0, 0);
      await repository.saveLastGenerated('rent', ts);

      final loaded = await repository.loadLastGenerated('rent');
      expect(loaded, ts);
    });

    test('lastGenerated は定義IDごとに独立している', () async {
      await repository.saveLastGenerated('rent', DateTime(2026, 6, 10));
      await repository.saveLastGenerated('other', DateTime(2026, 1, 1));

      expect(await repository.loadLastGenerated('rent'), DateTime(2026, 6, 10));
      expect(await repository.loadLastGenerated('other'), DateTime(2026, 1, 1));
    });
  });
}
