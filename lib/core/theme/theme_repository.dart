import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// テーマモード（ライト／ダーク／システム追従）の永続化リポジトリ
///
/// SharedPreferences を使用してユーザーが選択したテーマモードを保存・復元する。
/// アプリ再起動時にもユーザー選択が維持される。
class ThemeRepository {
  static const String _themeModeKey = 'kozuchi_theme_mode';

  const ThemeRepository();

  /// 保存されたテーマモードを読み込む
  ///
  /// 未保存の場合は null を返す（呼び出し側は ThemeMode.system をデフォルトとすべき）。
  Future<ThemeMode?> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_themeModeKey);
    if (value == null) return null;

    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => null,
    };
  }

  /// テーマモードを保存する
  Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await prefs.setString(_themeModeKey, value);
  }
}
