import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/features/budget/data/category_budget_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CategoryBudgetRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = const CategoryBudgetRepository();
  });

  group('CategoryBudgetRepository', () {
    test('未保存時は空マップ', () async {
      expect(await repository.loadBudgets('2026-06'), isEmpty);
    });

    test('saveBudget→loadBudgets 往復で復元される', () async {
      await repository.saveBudget('2026-06', '食費', 50000);
      await repository.saveBudget('2026-06', '趣味', 10000);

      final budgets = await repository.loadBudgets('2026-06');
      expect(budgets['食費'], 50000);
      expect(budgets['趣味'], 10000);
    });

    test('月ごとに独立して保存される', () async {
      await repository.saveBudget('2026-06', '食費', 50000);
      expect(await repository.loadBudgets('2026-07'), isEmpty);
    });

    test('saveBudget で同一カテゴリを上書きできる', () async {
      await repository.saveBudget('2026-06', '食費', 50000);
      await repository.saveBudget('2026-06', '食費', 60000);
      expect((await repository.loadBudgets('2026-06'))['食費'], 60000);
    });

    test('removeBudget でカテゴリを削除できる', () async {
      await repository.saveBudget('2026-06', '食費', 50000);
      await repository.saveBudget('2026-06', '趣味', 10000);

      await repository.removeBudget('2026-06', '食費');

      final budgets = await repository.loadBudgets('2026-06');
      expect(budgets.containsKey('食費'), isFalse);
      expect(budgets['趣味'], 10000);
    });

    test('破損データは空マップを返す', () async {
      SharedPreferences.setMockInitialValues({
        'kozuchi_category_budget_2026-06': 'not json',
      });
      expect(await repository.loadBudgets('2026-06'), isEmpty);
    });
  });
}
