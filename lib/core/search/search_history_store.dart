import 'package:shared_preferences/shared_preferences.dart';

import 'package:kozuchi/core/search/search_history.dart';

/// 検索履歴の永続化境界。
///
/// 読み出しは例外を投げず、未保存・破損時は空の [SearchHistory] を返すこと。
abstract class SearchHistoryStore {
  /// 保存済みの履歴を読み出す。
  Future<SearchHistory> load();

  /// 履歴を保存する。
  Future<void> save(SearchHistory history);
}

/// SharedPreferences 実装。key は [storageKey]、値は [SearchHistory.encode] の JSON 文字列。
class SharedPreferencesSearchHistoryStore implements SearchHistoryStore {
  /// 永続化キー。
  static const String storageKey = 'transaction_search_history_v1';

  const SharedPreferencesSearchHistoryStore();

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  @override
  Future<SearchHistory> load() async {
    try {
      final prefs = await _prefs();
      return SearchHistory.decode(prefs.getString(storageKey));
    } catch (_) {
      // プラグイン不在・型不一致・破損は空履歴へ倒す（アプリを落とさない）。
      return SearchHistory.empty();
    }
  }

  @override
  Future<void> save(SearchHistory history) async {
    try {
      final prefs = await _prefs();
      await prefs.setString(storageKey, history.encode());
    } catch (_) {
      // 保存失敗は機能を止めない（次回起動時に空履歴から再開するだけ）。
    }
  }
}