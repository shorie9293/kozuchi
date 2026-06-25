import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/domain/models/monthly_budget.dart';

/// 月間支出の永続化リポジトリ
///
/// SharedPreferences を使用して月ごとの累積支出額を保存・復元する。
/// キーは `kozuchi_expenditure_YYYY-MM` 形式。
class ExpenditureRepository {
  static const String _keyPrefix = 'kozuchi_expenditure_';

  const ExpenditureRepository();

  /// 指定月の支出合計を取得する
  Future<int> loadExpenditure(String yearMonth) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix$yearMonth';
    return prefs.getInt(key) ?? 0;
  }

  /// 現在月の支出合計を取得する
  Future<int> loadCurrentMonthExpenditure() async {
    final currentMonth = MonthlyBudget.currentYearMonth();
    return loadExpenditure(currentMonth);
  }

  /// 指定月の支出を加算する（差分を加えて保存）
  ///
  /// [additionalAmount] 分だけ当月の累積支出に加算する。
  Future<void> addExpenditure(int additionalAmount) async {
    final month = MonthlyBudget.currentYearMonth();
    final current = await loadExpenditure(month);
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix$month';
    await prefs.setInt(key, current + additionalAmount);
  }
}
