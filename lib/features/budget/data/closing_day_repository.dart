import 'package:shared_preferences/shared_preferences.dart';

import 'package:kozuchi/features/budget/domain/budget_period.dart';

/// 家計の締め日設定の永続化抽象。
abstract interface class ClosingDayRepository {
  /// 締め日を読み出す（未保存・破損・範囲外は既定値 1）。
  Future<int> load();

  /// 締め日を保存する（保存前に正規化する）。
  Future<void> save(int day);
}

/// SharedPreferences 実装。key は 'budget_closing_day_v1'、値は int。
class SharedPreferencesClosingDayRepository implements ClosingDayRepository {
  /// 永続化キー。
  static const String storageKey = 'budget_closing_day_v1';

  const SharedPreferencesClosingDayRepository();

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  @override
  Future<int> load() async {
    try {
      final prefs = await _prefs();
      final raw = prefs.getInt(storageKey);
      if (raw == null) return BudgetPeriodService.defaultClosingDay;
      // 範囲外の保存値は例外にせず既定値へ倒す。
      return BudgetPeriodService.normalize(raw);
    } catch (_) {
      // 型破損（文字列など）で getInt が投げた場合も既定値へ。
      return BudgetPeriodService.defaultClosingDay;
    }
  }

  @override
  Future<void> save(int day) async {
    final prefs = await _prefs();
    await prefs.setInt(storageKey, BudgetPeriodService.normalize(day));
  }
}

/// メモリ内実装（試練用）。保存値を保持する。
class InMemoryClosingDayRepository implements ClosingDayRepository {
  /// 保存内容（試練の検証に使える）。
  int? stored;

  @override
  Future<int> load() async {
    final value = stored;
    if (value == null) return BudgetPeriodService.defaultClosingDay;
    return BudgetPeriodService.normalize(value);
  }

  @override
  Future<void> save(int day) async {
    stored = BudgetPeriodService.normalize(day);
  }
}
