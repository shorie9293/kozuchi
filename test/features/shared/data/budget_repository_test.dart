import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/domain/models/monthly_budget.dart';
import 'package:kozuchi/features/shared/data/budget_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BudgetRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = const BudgetRepository();
  });

  group('BudgetRepository', () {
    test('saveBudget → loadBudget 往復で同一のMonthlyBudgetが復元される', () async {
      final budget = MonthlyBudget(yearMonth: '2026-06', amount: 150000);

      await repository.saveBudget(budget);
      final loaded = await repository.loadBudget('2026-06');

      expect(loaded, isNotNull);
      expect(loaded!.yearMonth, '2026-06');
      expect(loaded.amount, 150000);
    });

    test('loadBudget: 未保存時はnullが返る', () async {
      final result = await repository.loadBudget('2026-06');
      expect(result, isNull);
    });

    test('loadBudget: 不正なJSONではnullが返る', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('kozuchi_budget_2026-06', '破損データ{{{');

      final result = await repository.loadBudget('2026-06');
      expect(result, isNull);
    });

    test('異なる月の予算が互いに干渉しない', () async {
      final june = MonthlyBudget(yearMonth: '2026-06', amount: 100000);
      final july = MonthlyBudget(yearMonth: '2026-07', amount: 200000);

      await repository.saveBudget(june);
      await repository.saveBudget(july);

      final loadedJune = await repository.loadBudget('2026-06');
      final loadedJuly = await repository.loadBudget('2026-07');

      expect(loadedJune!.amount, 100000);
      expect(loadedJuly!.amount, 200000);
    });

    test('loadCurrentMonthBudget: 現在月の予算が読み出せる', () async {
      final currentMonth = MonthlyBudget.currentYearMonth();
      final budget = MonthlyBudget(yearMonth: currentMonth, amount: 80000);

      await repository.saveBudget(budget);
      final loaded = await repository.loadCurrentMonthBudget();

      expect(loaded, isNotNull);
      expect(loaded!.yearMonth, currentMonth);
      expect(loaded.amount, 80000);
    });

    test('loadCurrentMonthBudget: 未保存時はnullが返る', () async {
      final result = await repository.loadCurrentMonthBudget();
      expect(result, isNull);
    });
  });
}
