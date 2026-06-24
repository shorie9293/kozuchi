import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/domain/models/monthly_budget.dart';

/// 月間支出の永続化リポジトリ
///
/// SharedPreferences を使用して月ごとの総支出額を保存・復元する。
/// キーは `kozuchi_monthly_spent_YYYY-MM` 形式。
class MonthlySpendingRepository {
  static const String _keyPrefix = 'kozuchi_monthly_spent_';

  const MonthlySpendingRepository();

  /// 指定月の総支出額を取得する
  Future<int> getTotalSpent(String yearMonth) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix$yearMonth';
    return prefs.getInt(key) ?? 0;
  }

  /// 現在月の総支出額を取得する
  Future<int> getCurrentMonthSpent() async {
    final currentMonth = MonthlyBudget.currentYearMonth();
    return getTotalSpent(currentMonth);
  }

  /// 支出を追加する（引数の金額分だけ加算）
  Future<void> addSpending(String yearMonth, int amount) async {
    final current = await getTotalSpent(yearMonth);
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix$yearMonth';
    await prefs.setInt(key, current + amount);
  }

  /// 現在月に支出を追加する
  Future<void> addCurrentMonthSpending(int amount) async {
    final currentMonth = MonthlyBudget.currentYearMonth();
    await addSpending(currentMonth, amount);
  }

  /// 現在月の支出をリセットする（テスト用）
  Future<void> resetCurrentMonthSpending() async {
    final prefs = await SharedPreferences.getInstance();
    final currentMonth = MonthlyBudget.currentYearMonth();
    final key = '$_keyPrefix$currentMonth';
    await prefs.remove(key);
  }
}
