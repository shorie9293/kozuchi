import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/core/search/search_history.dart';

void main() {
  group('SearchHistory 正規化と追加', () {
    test('空の履歴は entries が空で isEmpty が true', () {
      final history = SearchHistory.empty();
      expect(history.entries, isEmpty);
      expect(history.isEmpty, isTrue);
      expect(history.length, 0);
    });

    test('add は前後の空白を除去して先頭に積む（新しい順）', () {
      var history = SearchHistory.empty();
      history = history.add('  ランチ  ');
      history = history.add('カフェ');
      expect(history.entries, ['カフェ', 'ランチ']);
    });

    test('全角空白は半角へ変換し、連続空白は1個に畳み込む', () {
      final history = SearchHistory.empty().add('　カフェ　　ラテ　');
      expect(history.entries, ['カフェ ラテ']);
    });

    test('空文字・空白のみは無視される', () {
      var history = SearchHistory.empty().add('カフェ');
      final same1 = history.add('');
      final same2 = history.add('   ');
      final same3 = history.add('　　');
      expect(same1.entries, ['カフェ']);
      expect(same2.entries, ['カフェ']);
      expect(same3.entries, ['カフェ']);
    });

    test('大小文字を無視した重複は先頭移動し、表記は最新で上書きされる', () {
      var history = SearchHistory.empty();
      history = history.add('Coffee');
      history = history.add('ランチ');
      history = history.add('COFFEE');
      expect(history.entries, ['COFFEE', 'ランチ']);
      expect(history.length, 2);
    });

    test('上限8件を超えると最古の語が捨てられる', () {
      var history = SearchHistory.empty();
      for (var i = 1; i <= 10; i++) {
        history = history.add('語$i');
      }
      expect(history.length, SearchHistory.maxEntries);
      expect(history.entries.first, '語10');
      expect(history.entries.last, '語3');
      expect(history.entries.contains('語1'), isFalse);
      expect(history.entries.contains('語2'), isFalse);
    });

    test('fromIterable は正規化・重複排除・上限を適用する', () {
      final history = SearchHistory.fromIterable([
        ' カフェ ',
        'カフェ',
        '',
        'ランチ',
        'COFFEE',
        'coffee',
      ]);
      expect(history.entries, ['カフェ', 'ランチ', 'COFFEE']);
    });

    test('add は元の履歴を変更しない（不変）', () {
      final original = SearchHistory.fromIterable(['カフェ']);
      final updated = original.add('ランチ');
      expect(original.entries, ['カフェ']);
      expect(updated.entries, ['ランチ', 'カフェ']);
    });
  });

  group('SearchHistory encode/decode', () {
    test('encode/decode は往復で内容と順序を保つ', () {
      final history = SearchHistory.fromIterable(['カフェ', 'ランチ', '交通費']);
      final restored = SearchHistory.decode(history.encode());
      expect(restored.entries, history.entries);
    });

    test('空の履歴は encode/decode できる', () {
      final history = SearchHistory.empty();
      expect(SearchHistory.decode(history.encode()).entries, isEmpty);
    });

    test('null・空文字は空履歴になる', () {
      expect(SearchHistory.decode(null).isEmpty, isTrue);
      expect(SearchHistory.decode('').isEmpty, isTrue);
    });

    test('破損した JSON は例外を投げず空履歴になる', () {
      expect(SearchHistory.decode('{壊れた').isEmpty, isTrue);
      expect(SearchHistory.decode('null').isEmpty, isTrue);
    });

    test('JSON がリストでない場合は空履歴になる', () {
      expect(SearchHistory.decode('{"a":1}').isEmpty, isTrue);
      expect(SearchHistory.decode('"カフェ"').isEmpty, isTrue);
    });

    test('リスト内の非文字列要素は読み飛ばす', () {
      final history = SearchHistory.decode('["カフェ",1,true,"ランチ"]');
      expect(history.entries, ['カフェ', 'ランチ']);
    });

    test('decode は正規化・重複排除・上限を適用する', () {
      final history = SearchHistory.decode(
        '[" カフェ ","カフェ","\\u3000ランチ\\u3000"]',
      );
      expect(history.entries, ['カフェ', 'ランチ']);
    });
  });
}