import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/domain/models/monthly_budget.dart';

/// 月間予算の永続化リポジトリ
///
/// SharedPreferences を使用して月ごとの予算データを保存・復元する。
/// キーは `kozuchi_budget_YYYY-MM` 形式。
class BudgetRepository {
  static const String _keyPrefix = 'kozuchi_budget_';

  const BudgetRepository();

  /// 指定月の予算を保存する
  Future<void> saveBudget(MonthlyBudget budget) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix${budget.yearMonth}';
    final jsonString = jsonEncode(budget.toJson());
    await prefs.setString(key, jsonString);
  }

  /// 指定月の予算を読み出す
  ///
  /// 保存データがない場合や破損している場合は null を返す。
  Future<MonthlyBudget?> loadBudget(String yearMonth) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix$yearMonth';
    final jsonString = prefs.getString(key);
    if (jsonString == null) return null;

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return MonthlyBudget.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// 現在月の予算を読み出す
  Future<MonthlyBudget?> loadCurrentMonthBudget() async {
    final currentMonth = MonthlyBudget.currentYearMonth();
    return loadBudget(currentMonth);
  }
}
