import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:kozuchi/features/budget/domain/budget_rollover.dart';

/// 予算繰り越し設定の永続化リポジトリ
///
/// SharedPreferences に JSON 文字列として保存する。
/// キーは `kozuchi_budget_rollover`。未保存時は無効（[RolloverSettings.defaults]）を返す。
class RolloverSettingsRepository {
  static const String _key = 'kozuchi_budget_rollover';

  const RolloverSettingsRepository();

  /// 設定を読み出す（未保存・破損時はデフォルト＝繰り越し無効）
  Future<RolloverSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString == null) return RolloverSettings.defaults;

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return RolloverSettings.fromJson(json);
    } catch (_) {
      return RolloverSettings.defaults;
    }
  }

  /// 設定を保存する
  Future<void> save(RolloverSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(settings.toJson()));
  }

  /// 繰り越しの有効/無効のみを更新する（他の設定は保持）
  Future<RolloverSettings> setEnabled(bool enabled) async {
    final current = await load();
    return _saveAndReturn(current.copyWith(enabled: enabled));
  }

  /// 繰越上限額を更新する（nullで上限なし）
  Future<RolloverSettings> setCap(int? cap) async {
    final current = await load();
    return _saveAndReturn(
      cap == null ? current.copyWith(clearCap: true) : current.copyWith(cap: cap),
    );
  }

  Future<RolloverSettings> _saveAndReturn(RolloverSettings settings) async {
    await save(settings);
    return settings;
  }
}
