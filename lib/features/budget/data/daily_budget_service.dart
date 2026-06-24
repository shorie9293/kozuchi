import 'package:kozuchi/domain/models/monthly_budget.dart';
import 'package:kozuchi/features/budget/domain/daily_budget.dart';
import 'package:kozuchi/features/shared/data/budget_repository.dart';
import 'package:kozuchi/features/budget/data/monthly_spending_repository.dart';

/// 日割り予算計算サービス
///
/// 月間予算と当月支出から、残日数で割った1日あたりの使用可能額を計算する。
class DailyBudgetService {
  final BudgetRepository _budgetRepo;
  final MonthlySpendingRepository _spendingRepo;

  const DailyBudgetService({
    BudgetRepository budgetRepo = const BudgetRepository(),
    MonthlySpendingRepository spendingRepo =
        const MonthlySpendingRepository(),
  })  : _budgetRepo = budgetRepo,
        _spendingRepo = spendingRepo;

  /// 現在月の日割り予算を計算する
  Future<DailyBudget> calculate() async {
    final currentMonth = MonthlyBudget.currentYearMonth();

    // 月間予算の取得
    final budget = await _budgetRepo.loadBudget(currentMonth);
    final monthlyBudget = budget?.amount ?? 0;

    // 当月の総支出額の取得
    final totalSpent = await _spendingRepo.getTotalSpent(currentMonth);

    // 残日数の計算（今日を含む）
    final remainingDays = _calculateRemainingDays();

    return DailyBudget(
      monthlyBudget: monthlyBudget,
      totalSpent: totalSpent,
      remainingDays: remainingDays,
    );
  }

  /// 支出を記録する（TrialQuestのofferring時に呼ばれる）
  Future<void> recordSpending(int amount) async {
    final currentMonth = MonthlyBudget.currentYearMonth();
    await _spendingRepo.addSpending(currentMonth, amount);
  }

  /// 現在月の支出をリセットする（テスト用）
  Future<void> resetSpending() async {
    await _spendingRepo.resetCurrentMonthSpending();
  }

  /// 今日から月末までの残日数を計算する
  static int _calculateRemainingDays() {
    final now = DateTime.now();
    // 月末日を求める（翌月の0日 = 当月の最終日）
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
    // 今日を含む残日数
    final remaining = lastDayOfMonth.day - now.day + 1;
    return remaining.clamp(0, 31);
  }
}
