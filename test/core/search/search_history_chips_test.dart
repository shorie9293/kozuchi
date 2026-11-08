import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/core/search/search_history.dart';
import 'package:kozuchi/core/search/search_history_chips.dart';
import 'package:kozuchi/core/search/search_history_store.dart';
import 'package:kozuchi/features/transaction_filter/domain/models/transaction_filter.dart';
import 'package:kozuchi/features/transaction_filter/presentation/transaction_query_app_keys.dart';
import 'package:kozuchi/features/transaction_filter/presentation/widgets/transaction_filter_bar.dart';

/// メモリ上の履歴ストア（試練用フェイク）。
class _FakeSearchHistoryStore implements SearchHistoryStore {
  _FakeSearchHistoryStore([SearchHistory? initial])
      : _stored = initial ?? SearchHistory.empty();

  SearchHistory _stored;
  int saveCount = 0;

  SearchHistory get stored => _stored;

  @override
  Future<SearchHistory> load() async => _stored;

  @override
  Future<void> save(SearchHistory history) async {
    _stored = history;
    saveCount++;
  }
}

void main() {
  group('SearchHistoryChips', () {
    Future<void> pumpChips(
      WidgetTester tester, {
      List<String> entries = const [],
      ValueChanged<String>? onSelected,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchHistoryChips(
              entries: entries,
              onSelected: onSelected ?? (_) {},
            ),
          ),
        ),
      );
    }

    testWidgets('履歴が空ならチップを描画しない', (tester) async {
      await pumpChips(tester);

      expect(find.byType(ActionChip), findsNothing);
      expect(find.byType(Wrap), findsNothing);
    });

    testWidgets('履歴の各語をActionChipで新しい順に表示する', (tester) async {
      await pumpChips(tester, entries: const ['カフェ', 'ランチ', '交通費']);

      expect(find.byType(ActionChip), findsNWidgets(3));
      expect(find.text('カフェ'), findsOneWidget);
      expect(find.text('ランチ'), findsOneWidget);
      expect(find.text('交通費'), findsOneWidget);

      final labels = tester
          .widgetList<ActionChip>(find.byType(ActionChip))
          .map((chip) => (chip.label as Text).data)
          .toList();
      expect(labels, ['カフェ', 'ランチ', '交通費']);
    });

    testWidgets('チップをタップすると選択語がonSelectedへ渡る', (tester) async {
      String? selected;
      await pumpChips(
        tester,
        entries: const ['カフェ', 'ランチ'],
        onSelected: (term) => selected = term,
      );

      await tester.tap(find.text('ランチ'));
      await tester.pump();

      expect(selected, 'ランチ');
    });

    testWidgets('Wrapで折り返し配置される', (tester) async {
      await pumpChips(tester, entries: const ['A', 'B']);

      expect(find.byType(Wrap), findsOneWidget);
      final wrap = tester.widget<Wrap>(find.byType(Wrap));
      expect(wrap.children.length, 2);
    });

    testWidgets('検索履歴のセマンティクスラベルを持つ', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpChips(tester, entries: const ['カフェ']);

      expect(find.bySemanticsLabel('検索履歴'), findsOneWidget);
      handle.dispose();
    });
  });

  group('TransactionFilterBar × 検索履歴チップ配線', () {
    Future<void> pumpBar(
      WidgetTester tester, {
      required SearchHistoryStore store,
      TransactionFilter initialFilter = const TransactionFilter(),
      ValueChanged<TransactionFilter>? onChanged,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionFilterBar(
              initialFilter: initialFilter,
              onChanged: onChanged ?? (_) {},
              searchHistoryStore: store,
            ),
          ),
        ),
      );
      // 履歴の非同期読み出しを反映させる（不確定アニメーションは無いので pump で足りる）。
      await tester.pump();
      await tester.pump();
    }

    testWidgets('保存済み履歴を読み出して検索欄直下にチップ表示する', (tester) async {
      final store = _FakeSearchHistoryStore(
        SearchHistory.fromIterable(['カフェ', 'ランチ']),
      );
      await pumpBar(tester, store: store);

      expect(find.text('カフェ'), findsOneWidget);
      expect(find.text('ランチ'), findsOneWidget);
    });

    testWidgets('履歴が空ならチップを表示しない', (tester) async {
      final store = _FakeSearchHistoryStore();
      await pumpBar(tester, store: store);

      expect(find.byType(ActionChip), findsNothing);
    });

    testWidgets('チップをタップすると検索欄が更新され絞込が発火する', (tester) async {
      final store = _FakeSearchHistoryStore(
        SearchHistory.fromIterable(['カフェ']),
      );
      TransactionFilter? emitted;
      await pumpBar(
        tester,
        store: store,
        onChanged: (f) => emitted = f,
      );

      await tester.tap(find.text('カフェ'));
      await tester.pump();

      final field = tester.widget<TextField>(
        find.byKey(TransactionQueryAppKeys.keywordField),
      );
      expect(field.controller!.text, 'カフェ');
      expect(emitted, isNotNull);
      expect(emitted!.keyword, 'カフェ');
    });

    testWidgets('onSubmitted で現在語が履歴へ保存される', (tester) async {
      final store = _FakeSearchHistoryStore();
      await pumpBar(tester, store: store);

      await tester.enterText(
        find.byKey(TransactionQueryAppKeys.keywordField),
        '　カフェ　ラテ ',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();

      expect(store.saveCount, 1);
      expect(store.stored.entries, ['カフェ ラテ']);
      expect(find.text('カフェ ラテ'), findsOneWidget);
    });

    testWidgets('空語の onSubmitted では保存しない', (tester) async {
      final store = _FakeSearchHistoryStore();
      await pumpBar(tester, store: store);

      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();

      expect(store.saveCount, 0);
      expect(store.stored.isEmpty, isTrue);
    });

    testWidgets('dispose 時に現在語が非空なら保存する', (tester) async {
      final store = _FakeSearchHistoryStore();
      await pumpBar(tester, store: store);

      await tester.enterText(
        find.byKey(TransactionQueryAppKeys.keywordField),
        '交通費',
      );
      await tester.pump();

      await tester
          .pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
      await tester.pump();

      expect(store.saveCount, 1);
      expect(store.stored.entries, ['交通費']);
    });

    testWidgets('dispose 時に空語なら保存しない', (tester) async {
      final store = _FakeSearchHistoryStore();
      await pumpBar(tester, store: store);

      await tester
          .pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
      await tester.pump();

      expect(store.saveCount, 0);
    });
  });
}
