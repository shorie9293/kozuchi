import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/tags/domain/models/expense_tag.dart';
import 'package:kozuchi/features/transaction_filter/domain/models/transaction_filter.dart';
import 'package:kozuchi/features/transaction_filter/presentation/transaction_query_app_keys.dart';
import 'package:kozuchi/features/transaction_filter/presentation/widgets/transaction_filter_bar.dart';

void main() {
  group('TransactionFilterBar（キーワード・カテゴリ・タグ）', () {
    /// Helper: pump TransactionFilterBar and capture onChange emissions.
    Future<void> pumpBar(
      WidgetTester tester, {
      TransactionFilter initialFilter = const TransactionFilter(),
      List<String> availableCategories = const [],
      List<ExpenseTag> availableTags = const [],
      ValueChanged<TransactionFilter>? onChanged,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionFilterBar(
              initialFilter: initialFilter,
              onChanged: onChanged ?? (_) {},
              availableCategories: availableCategories,
              availableTags: availableTags,
            ),
          ),
        ),
      );
    }

    // ── キーワード入力 ──────────────────────────────

    testWidgets('キーワード入力でonChangedがkeyword付きTransactionFilterを発火する',
        (tester) async {
      TransactionFilter? emitted;
      await pumpBar(tester, onChanged: (f) => emitted = f);

      await tester.enterText(
        find.byKey(TransactionQueryAppKeys.keywordField),
        'コンビニ',
      );
      await tester.pump();

      expect(emitted, isNotNull);
      expect(emitted!.keyword, 'コンビニ');
      expect(emitted!.hasKeyword, isTrue);
    });

    testWidgets('クリアボタンでキーワードが空に戻る', (tester) async {
      TransactionFilter? emitted;
      await pumpBar(
        tester,
        initialFilter: const TransactionFilter(keyword: '食費'),
        onChanged: (f) => emitted = f,
      );

      // クリアボタンが表示されている
      expect(
        find.byKey(TransactionQueryAppKeys.keywordClear),
        findsOneWidget,
      );

      await tester.tap(find.byKey(TransactionQueryAppKeys.keywordClear));
      await tester.pump();

      expect(emitted, isNotNull);
      expect(emitted!.keyword, '');
      expect(emitted!.hasKeyword, isFalse);
    });

    testWidgets('キーワードが空のときはクリアボタンが表示されない', (tester) async {
      await pumpBar(tester);

      expect(
        find.byKey(TransactionQueryAppKeys.keywordClear),
        findsNothing,
      );
    });

    testWidgets('キーワードフィールドに検索アイコン（プレフィックス）が表示される',
        (tester) async {
      await pumpBar(tester);

      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    // ── カテゴリチップ ──────────────────────────────

    testWidgets('カテゴリチップがavailableCategoriesの数だけ表示される', (tester) async {
      await pumpBar(
        tester,
        availableCategories: const ['食費', '交通費', '娯楽'],
      );

      expect(find.text('食費'), findsOneWidget);
      expect(find.text('交通費'), findsOneWidget);
      expect(find.text('娯楽'), findsOneWidget);
    });

    testWidgets('カテゴリチップ選択でonChangedがcategories付きで発火する', (tester) async {
      TransactionFilter? emitted;
      await pumpBar(
        tester,
        availableCategories: const ['食費', '交通費'],
        onChanged: (f) => emitted = f,
      );

      await tester.tap(find.byKey(TransactionQueryAppKeys.categoryChip('食費')));
      await tester.pump();

      expect(emitted, isNotNull);
      expect(emitted!.categories, {'食費'});
    });

    testWidgets('カテゴリチップ解除でonChangedが空categories付きで発火する', (tester) async {
      TransactionFilter? emitted;
      await pumpBar(
        tester,
        initialFilter: const TransactionFilter(categories: {'食費'}),
        availableCategories: const ['食費', '交通費'],
        onChanged: (f) => emitted = f,
      );

      // 選択状態で表示されている
      final chip = tester.widget<ChoiceChip>(
        find.byKey(TransactionQueryAppKeys.categoryChip('食費')),
      );
      expect(chip.selected, isTrue);

      await tester.tap(find.byKey(TransactionQueryAppKeys.categoryChip('食費')));
      await tester.pump();

      expect(emitted, isNotNull);
      expect(emitted!.categories, isEmpty);
    });

    // ── タグチップ ──────────────────────────────

    testWidgets('タグチップがタグ名で表示される', (tester) async {
      await pumpBar(
        tester,
        availableTags: const [
          ExpenseTag(id: 't1', name: '旅行'),
          ExpenseTag(id: 't2', name: 'サブスク'),
        ],
      );

      expect(find.text('旅行'), findsOneWidget);
      expect(find.text('サブスク'), findsOneWidget);
    });

    testWidgets('タグチップ選択でonChangedがtagIds（タグID）付きで発火する', (tester) async {
      TransactionFilter? emitted;
      await pumpBar(
        tester,
        availableTags: const [ExpenseTag(id: 't1', name: '旅行')],
        onChanged: (f) => emitted = f,
      );

      await tester.tap(find.byKey(TransactionQueryAppKeys.tagChip('t1')));
      await tester.pump();

      expect(emitted, isNotNull);
      expect(emitted!.tagIds, {'t1'});
    });

    testWidgets('タグチップ解除でonChangedが空tagIds付きで発火する', (tester) async {
      TransactionFilter? emitted;
      await pumpBar(
        tester,
        initialFilter: const TransactionFilter(tagIds: {'t1'}),
        availableTags: const [ExpenseTag(id: 't1', name: '旅行')],
        onChanged: (f) => emitted = f,
      );

      await tester.tap(find.byKey(TransactionQueryAppKeys.tagChip('t1')));
      await tester.pump();

      expect(emitted, isNotNull);
      expect(emitted!.tagIds, isEmpty);
    });

    // ── 初期値復元 ──────────────────────────────

    testWidgets('初期フィルタからキーワード・カテゴリ・タグの選択状態が復元される',
        (tester) async {
      await pumpBar(
        tester,
        initialFilter: const TransactionFilter(
          keyword: 'コンビニ',
          categories: {'食費'},
          tagIds: {'t1'},
        ),
        availableCategories: const ['食費', '交通費'],
        availableTags: const [ExpenseTag(id: 't1', name: '旅行')],
      );

      // キーワードが復元されている
      final field = tester.widget<TextField>(
        find.byKey(TransactionQueryAppKeys.keywordField),
      );
      expect(field.controller!.text, 'コンビニ');

      // カテゴリチップが選択状態
      final categoryChip = tester.widget<ChoiceChip>(
        find.byKey(TransactionQueryAppKeys.categoryChip('食費')),
      );
      expect(categoryChip.selected, isTrue);

      // タグチップが選択状態
      final tagChip = tester.widget<ChoiceChip>(
        find.byKey(TransactionQueryAppKeys.tagChip('t1')),
      );
      expect(tagChip.selected, isTrue);
    });

    // ── 既存機能の非回帰 ──────────────────────────────

    testWidgets('種別トグルはキーワード・チップ選択状態を保持したまま発火する',
        (tester) async {
      TransactionFilter? emitted;
      await pumpBar(
        tester,
        initialFilter: const TransactionFilter(keyword: 'コンビニ'),
        availableCategories: const ['食費'],
        onChanged: (f) => emitted = f,
      );

      await tester.tap(find.text('収入'));
      await tester.pump();

      expect(emitted, isNotNull);
      expect(emitted!.type, TransactionFilterType.income);
      expect(emitted!.keyword, 'コンビニ');
      expect(emitted!.categories, isEmpty);
    });

    testWidgets('カテゴリ・タグ未指定でも既存UI（種別・日付範囲）は表示される',
        (tester) async {
      await pumpBar(tester);

      expect(find.text('全件'), findsOneWidget);
      expect(find.text('〜'), findsOneWidget);
      expect(
        find.byKey(TransactionQueryAppKeys.categoryChip('食費')),
        findsNothing,
      );
    });

    testWidgets('Semanticsラベルが付与されている', (tester) async {
      await pumpBar(
        tester,
        availableCategories: const ['食費'],
        availableTags: const [ExpenseTag(id: 't1', name: '旅行')],
      );

      bool hasSemanticsLabel(String label, Widget widget) =>
          widget is Semantics && widget.properties.label == label;

      expect(
        find.byWidgetPredicate((w) => hasSemanticsLabel('キーワード検索フィルタ', w)),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) => hasSemanticsLabel('カテゴリフィルタ', w)),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) => hasSemanticsLabel('タグフィルタ', w)),
        findsOneWidget,
      );
    });
  });
}