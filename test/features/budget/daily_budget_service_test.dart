import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/features/budget/data/daily_budget_service.dart';
import 'package:kozuchi/features/budget/data/monthly_spending_repository.dart';
import 'package:kozuchi/domain/models/monthly_budget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DailyBudgetService.recordSpending', () {
    test('支出を記録するとMonthlySpendingRepositoryに反映されること', () async {
      SharedPreferences.setMockInitialValues({});
      const service = DailyBudgetService();
      const spendingRepo = MonthlySpendingRepository();
      final currentMonth = MonthlyBudget.currentYearMonth();

      expect(await spendingRepo.getTotalSpent(currentMonth), 0);

      await service.recordSpending(5000);

      expect(await spendingRepo.getTotalSpent(currentMonth), 5000);
    });

    test('複数回の支出記録が累積されること', () async {
      SharedPreferences.setMockInitialValues({});
      const service = DailyBudgetService();
      const spendingRepo = MonthlySpendingRepository();
      final currentMonth = MonthlyBudget.currentYearMonth();

      await service.recordSpending(1000);
      await service.recordSpending(2000);
      await service.recordSpending(3000);

      expect(await spendingRepo.getTotalSpent(currentMonth), 6000);
    });
  });
}
