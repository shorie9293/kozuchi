import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/core/search/search_history.dart';
import 'package:kozuchi/core/search/search_history_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharedPreferencesSearchHistoryStore', () {
    test('保存した履歴を読み出せる', () async {
      SharedPreferences.setMockInitialValues({});
      const store = SharedPreferencesSearchHistoryStore();
      final history = SearchHistory.fromIterable(['カフェ', 'ランチ']);

      await store.save(history);

      final loaded = await store.load();
      expect(loaded.entries, ['カフェ', 'ランチ']);
    });

    test('保存キーは transaction_search_history_v1', () async {
      SharedPreferences.setMockInitialValues({});
      const store = SharedPreferencesSearchHistoryStore();

      await store.save(SearchHistory.fromIterable(['カフェ']));

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(SharedPreferencesSearchHistoryStore.storageKey),
        '["カフェ"]',
      );
      expect(SharedPreferencesSearchHistoryStore.storageKey,
          'transaction_search_history_v1');
    });

    test('未保存なら空履歴を返す', () async {
      SharedPreferences.setMockInitialValues({});
      const store = SharedPreferencesSearchHistoryStore();

      final loaded = await store.load();
      expect(loaded.isEmpty, isTrue);
    });

    test('破損した保存値でも例外を投げず空履歴を返す', () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesSearchHistoryStore.storageKey: '{壊れた',
      });
      const store = SharedPreferencesSearchHistoryStore();

      final loaded = await store.load();
      expect(loaded.isEmpty, isTrue);
    });

    test('空文字の保存値でも空履歴を返す', () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesSearchHistoryStore.storageKey: '',
      });
      const store = SharedPreferencesSearchHistoryStore();

      final loaded = await store.load();
      expect(loaded.isEmpty, isTrue);
    });

    test('上書き保存は最新の履歴に置き換わる', () async {
      SharedPreferences.setMockInitialValues({});
      const store = SharedPreferencesSearchHistoryStore();

      await store.save(SearchHistory.fromIterable(['古い語']));
      await store.save(SearchHistory.fromIterable(['新しい語']));

      final loaded = await store.load();
      expect(loaded.entries, ['新しい語']);
    });
  });
}