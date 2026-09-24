import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kozuchi/features/category_ledger/data/category_ledger_repository.dart';
import 'package:kozuchi/features/category_ledger/domain/category_ledger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharedPreferencesCategoryLedgerRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('不変条件7: 未保存時は既定台帳', () async {
      final repo = const SharedPreferencesCategoryLedgerRepository();
      final ledger = await repo.loadLedger();
      expect(ledger, CategoryLedger.defaults());
      expect(ledger.isDefault, isTrue);
    });

    test('不変条件7: save → load 往復で順序保持', () async {
      final repo = const SharedPreferencesCategoryLedgerRepository();
      final ledger = CategoryLedger(['z', 'あ', 'm']);
      await repo.saveLedger(ledger);
      final loaded = await repo.loadLedger();
      expect(loaded.categories, ['z', 'あ', 'm']);
      expect(loaded, ledger);
    });

    test('不変条件7: 破損JSONは全て既定台帳にフォールバック', () async {
      final brokenValues = <String>['{', '123', '[1,2]', '[]'];
      for (final key in brokenValues) {
        SharedPreferences.setMockInitialValues({
          SharedPreferencesCategoryLedgerRepository.storageKey: key,
        });
        final repo = const SharedPreferencesCategoryLedgerRepository();
        final ledger = await repo.loadLedger();
        expect(ledger, CategoryLedger.defaults(), reason: '破損値: $key');
      }
    });
  });

  group('InMemoryCategoryLedgerRepository', () {
    test('未保存時は既定台帳・往復', () async {
      final repo = InMemoryCategoryLedgerRepository();
      expect(await repo.loadLedger(), CategoryLedger.defaults());
      final ledger = CategoryLedger(['a', 'b']);
      await repo.saveLedger(ledger);
      expect(await repo.loadLedger(), ledger);
    });
  });

  group('NoopCategoryLedgerRepository', () {
    test('load常に既定 / saveは何もしない', () async {
      final repo = const NoopCategoryLedgerRepository();
      expect(await repo.loadLedger(), CategoryLedger.defaults());
      await repo.saveLedger(CategoryLedger(['x']));
      expect(await repo.loadLedger(), CategoryLedger.defaults());
    });
  });
}