import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/domain/models/monthly_budget.dart';

/// 月間予算の永続化リポジトリ
///
/// SharedPreferences を使用して月ごとの予算データを保存・復元する。
/// キーは `kozuchi_budget_YYYY-MM` 形式。
/// 月間支出の追跡と予算警告閾値の管理も行う。
class BudgetRepository {
  static const String _keyPrefix = 'kozuchi_budget_';
  static const String _spendingKeyPrefix = 'kozuchi_monthly_spending_';
  static const String _thresholdKey = 'kozuchi_budget_warning_threshold';

  /// デフォルトの警告閾値（80%）
  static const double defaultWarningThreshold = 0.8;

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

  // ─── 月間支出トラッキング ────────────────────────────

  /// 指定月の支出合計を読み出す
  Future<int> loadMonthlySpending(String yearMonth) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_spendingKeyPrefix$yearMonth';
    return prefs.getInt(key) ?? 0;
  }

  /// 現在月の支出合計を読み出す
  Future<int> loadCurrentMonthSpending() async {
    final currentMonth = MonthlyBudget.currentYearMonth();
    return loadMonthlySpending(currentMonth);
  }

  /// 指定月の支出合計を保存する
  Future<void> saveMonthlySpending(String yearMonth, int total) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_spendingKeyPrefix$yearMonth';
    await prefs.setInt(key, total);
  }

  /// 現在月の支出に指定額を加算する
  Future<int> addToCurrentMonthSpending(int amount) async {
    final currentMonth = MonthlyBudget.currentYearMonth();
    final current = await loadMonthlySpending(currentMonth);
    final newTotal = current + amount;
    await saveMonthlySpending(currentMonth, newTotal);
    return newTotal;
  }

  // ─── 警告閾値管理 ────────────────────────────────────

  /// 警告閾値を読み出す（0.0〜1.0、デフォルト0.8）
  Future<double> loadWarningThreshold() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_thresholdKey) ?? defaultWarningThreshold;
  }

  /// 警告閾値を保存する
  Future<void> saveWarningThreshold(double threshold) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_thresholdKey, threshold.clamp(0.0, 1.0));
  }
}
