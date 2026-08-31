import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/domain/models/monthly_budget.dart';

/// カテゴリ別予算の永続化リポジトリ
///
/// SharedPreferences を使用して、月ごとにカテゴリ名 → 予算上限額 のマップを
/// 保存・復元する。キーは `kozuchi_category_budget_YYYY-MM` 形式（JSON文字列）。
class CategoryBudgetRepository {
  static const String _keyPrefix = 'kozuchi_category_budget_';

  const CategoryBudgetRepository();

  /// 指定月のカテゴリ別予算マップを取得する（未設定・破損時は空マップ）
  Future<Map<String, int>> loadBudgets(String yearMonth) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix$yearMonth';
    final jsonString = prefs.getString(key);
    if (jsonString == null) return {};

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return json.map((category, value) => MapEntry(category, value as int));
    } catch (_) {
      return {};
    }
  }

  /// 現在月のカテゴリ別予算マップを取得する
  Future<Map<String, int>> loadCurrentMonthBudgets() async {
    final currentMonth = MonthlyBudget.currentYearMonth();
    return loadBudgets(currentMonth);
  }

  /// 指定月のカテゴリに予算上限を設定する（既存は上書き）
  Future<void> saveBudget(
    String yearMonth,
    String category,
    int amount,
  ) async {
    final budgets = await loadBudgets(yearMonth);
    budgets[category] = amount;
    await _save(yearMonth, budgets);
  }

  /// 指定月のカテゴリ予算を削除する
  Future<void> removeBudget(String yearMonth, String category) async {
    final budgets = await loadBudgets(yearMonth);
    budgets.remove(category);
    await _save(yearMonth, budgets);
  }

  Future<void> _save(String yearMonth, Map<String, int> budgets) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix$yearMonth';
    await prefs.setString(key, jsonEncode(budgets));
  }
}
