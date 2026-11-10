import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/transaction_filter/domain/models/transaction_filter.dart';
import 'package:kozuchi/features/transaction_history/presentation/screens/transaction_history_page.dart';
import 'package:kozuchi/features/transaction_history/presentation/state/transaction_controller.dart';
import 'package:kozuchi/features/transaction_history/presentation/widgets/transaction_list_item.dart';
import 'package:kozuchi/features/transaction_history/presentation/widgets/transaction_list_widget.dart';
import 'package:kozuchi/features/undo/presentation/undo_snack_bar.dart';

/// 一括選択・一括削除の試練用フェイクコントローラ。
///
/// [deleteTransaction] / [restoreTransaction] を記録可能なフェイクに差し替え、
/// 削除呼び出しの件数・順序を検証できるようにする。
class FakeTransactionController extends TransactionController {
  FakeTransactionController({
    required List<TransactionModel> transactions,
    TransactionFilter filter = const TransactionFilter(),
  })  : _transactions = List<TransactionModel>.of(transactions),
        _filter = filter;

  final List<TransactionModel> _transactions;
  TransactionFilter _filter;

  /// 削除実行された取引（呼び出し順）。
  final List<TransactionModel> deleteCalls = <TransactionModel>[];

  /// 復元実行された取引 ID（呼び出し順）。
  final List<String> restoredIds = <String>[];

  /// true にすると削除が全件失敗する。
  bool failDelete = false;

  @override
  List<TransactionModel> get transactions =>
      List<TransactionModel>.unmodifiable(_transactions);

  @override
  TransactionFilter get filter => _filter;

  @override
  bool get isLoading => false;

  @override
  String? get error => null;

  @override
  void updateFilter(TransactionFilter filter) {
    if (filter == _filter) return;
    _filter = filter;
    notifyListeners();
  }

  @override
  Future<void> fetchTransactions() async {}

  @override
  Future<void> refetch() async {}

  @override
  Future<bool> deleteTransaction(TransactionModel transaction) async {
    deleteCalls.add(transaction);
    if (failDelete) return false;
    _transactions.removeWhere((tx) => tx.id == transaction.id);
    return true;
  }

  @override
  Future<bool> restoreTransaction(TransactionModel transaction) async {
    restoredIds.add(transaction.id ?? '');
    return true;
  }
}

void main() {
  setUp(() {
    // タグリポジトリ（SharedPreferences）の初期化を試練環境で満たす。
    SharedPreferences.setMockInitialValues({});
  });

  /// 取引を1件生成する。
  TransactionModel makeTx(
    String id, {
    int amount = -1000,
    String purpose = 'ランチ',
    String category = '食費',
    String datetime = '2026-06-15T12:00:00',
  }) {
    return TransactionModel(
      id: id,
      amount: amount,
      purpose: purpose,
      category: category,
      datetime: datetime,
    );
  }

  /// 画面を pump して初期非同期処理（タグ読込）を完了させる。
  Future<FakeTransactionController> pumpPage(
    WidgetTester tester, {
    required List<TransactionModel> transactions,
    TransactionFilter filter = const TransactionFilter(),
  }) async {
    final controller = FakeTransactionController(
      transactions: transactions,
      filter: filter,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: TransactionHistoryPage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  /// 3件（a/b/c）の標準データ。
  List<TransactionModel> threeTx() => [
        makeTx('a', purpose: 'ランチ', category: '食費'),
        makeTx('b', purpose: 'バス', category: '交通費'),
        makeTx('c', purpose: '夕食', category: '食費'),
      ];

  group('一括選択モードの基本操作', () {
    testWidgets('長押しで選択モードに入り AppBar が「1件選択」になる', (tester) async {
      await pumpPage(tester, transactions: threeTx());

      await tester.longPress(find.byKey(HistorySelectionKeys.item('a')));
      await tester.pumpAndSettle();

      expect(find.text('1件選択'), findsOneWidget);
      expect(find.text('取引履歴'), findsNothing);
    });

    testWidgets('選択モードでは各行の先頭にチェックボックスが出る', (tester) async {
      await pumpPage(tester, transactions: threeTx());

      // 通常モードではチェックボックス無し
      expect(find.byKey(HistorySelectionKeys.checkbox('a')), findsNothing);

      await tester.longPress(find.byKey(HistorySelectionKeys.item('a')));
      await tester.pumpAndSettle();

      expect(find.byKey(HistorySelectionKeys.checkbox('a')), findsOneWidget);
      expect(find.byKey(HistorySelectionKeys.checkbox('b')), findsOneWidget);
      // 長押しした行は選択済み
      final checkbox = tester.widget<Checkbox>(
        find.byKey(HistorySelectionKeys.checkbox('a')),
      );
      expect(checkbox.value, isTrue);
    });

    testWidgets('2件目をタップすると「2件選択」、再タップで「1件選択」に戻る', (tester) async {
      await pumpPage(tester, transactions: threeTx());

      await tester.longPress(find.byKey(HistorySelectionKeys.item('a')));
      await tester.pumpAndSettle();
      expect(find.text('1件選択'), findsOneWidget);

      await tester.tap(find.byKey(HistorySelectionKeys.item('b')));
      await tester.pumpAndSettle();
      expect(find.text('2件選択'), findsOneWidget);

      await tester.tap(find.byKey(HistorySelectionKeys.item('b')));
      await tester.pumpAndSettle();
      expect(find.text('1件選択'), findsOneWidget);
    });

    testWidgets('選択中の行は Card が primaryContainer で強調される', (tester) async {
      await pumpPage(tester, transactions: threeTx());

      await tester.longPress(find.byKey(HistorySelectionKeys.item('a')));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(TransactionListWidget));
      final expected = Theme.of(context).colorScheme.primaryContainer;
      final card = tester.widget<Card>(
        find.byKey(HistorySelectionKeys.item('a')),
      );
      expect(card.color, expected);
    });

    testWidgets('チェックボックスのタップでも選択がトグルする', (tester) async {
      await pumpPage(tester, transactions: threeTx());

      await tester.longPress(find.byKey(HistorySelectionKeys.item('a')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(HistorySelectionKeys.checkbox('c')));
      await tester.pumpAndSettle();
      expect(find.text('2件選択'), findsOneWidget);
    });
  });

  group('全選択と解除', () {
    testWidgets('全選択で表示中の全件が選択され、解除で通常モードに戻る', (tester) async {
      await pumpPage(tester, transactions: threeTx());

      await tester.longPress(find.byKey(HistorySelectionKeys.item('a')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(HistorySelectionKeys.selectAll));
      await tester.pumpAndSettle();
      expect(find.text('3件選択'), findsOneWidget);

      await tester.tap(find.byKey(HistorySelectionKeys.clearButton));
      await tester.pumpAndSettle();

      expect(find.text('取引履歴'), findsOneWidget);
      expect(find.byKey(HistorySelectionKeys.checkbox('a')), findsNothing);
    });

    testWidgets('AppBar の閉じるで選択が解除される', (tester) async {
      await pumpPage(tester, transactions: threeTx());

      await tester.longPress(find.byKey(HistorySelectionKeys.item('a')));
      await tester.pumpAndSettle();
      expect(find.text('1件選択'), findsOneWidget);

      await tester.tap(find.byKey(HistorySelectionKeys.close));
      await tester.pumpAndSettle();

      expect(find.text('取引履歴'), findsOneWidget);
      expect(find.text('1件選択'), findsNothing);
    });
  });

  group('一括削除', () {
    testWidgets('削除ボタンで確認ダイアログが表示される', (tester) async {
      await pumpPage(tester, transactions: threeTx());

      await tester.longPress(find.byKey(HistorySelectionKeys.item('a')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(HistorySelectionKeys.item('b')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(HistorySelectionKeys.deleteButton));
      await tester.pumpAndSettle();

      expect(find.text('選択した 2件を削除します。取り消せます。'), findsOneWidget);
    });

    testWidgets('確認をキャンセルすると1件も削除されず選択が維持される', (tester) async {
      final controller = await pumpPage(tester, transactions: threeTx());

      await tester.longPress(find.byKey(HistorySelectionKeys.item('a')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(HistorySelectionKeys.item('b')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(HistorySelectionKeys.deleteButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(HistorySelectionKeys.cancelDelete));
      await tester.pumpAndSettle();

      expect(controller.deleteCalls, isEmpty);
      expect(find.text('2件選択'), findsOneWidget);
      expect(find.byKey(HistorySelectionKeys.checkbox('a')), findsOneWidget);
    });

    testWidgets('確定で選択件数分だけ削除され、成功後に選択が解除される', (tester) async {
      final controller = await pumpPage(tester, transactions: threeTx());

      await tester.longPress(find.byKey(HistorySelectionKeys.item('a')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(HistorySelectionKeys.item('b')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(HistorySelectionKeys.deleteButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(HistorySelectionKeys.confirmDelete));
      await tester.pumpAndSettle();

      expect(controller.deleteCalls.length, 2);
      expect(
        controller.deleteCalls.map((tx) => tx.id).toList(),
        <String>['a', 'b'],
      );
      // 選択解除され通常モード（AppBar タイトル）に戻る
      expect(find.text('取引履歴'), findsOneWidget);
      expect(find.text('2件選択'), findsNothing);
      // 削除成功の通知
      expect(find.text('2件の取引を削除しました'), findsOneWidget);
    });

    testWidgets('削除が全件失敗したら選択を解除しつつ失敗を報せる', (tester) async {
      final controller = await pumpPage(tester, transactions: threeTx());
      controller.failDelete = true;

      await tester.longPress(find.byKey(HistorySelectionKeys.item('a')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(HistorySelectionKeys.deleteButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(HistorySelectionKeys.confirmDelete));
      await tester.pumpAndSettle();

      expect(controller.deleteCalls.length, 1);
      expect(find.text('この取引は削除できません'), findsOneWidget);
      expect(find.text('取引履歴'), findsOneWidget);
    });
  });

  group('絞込中の安全性', () {
    testWidgets('絞込中は絞込外の取引が削除されない', (tester) async {
      // 支出のみ表示（収入2件は絞込外）
      final controller = await pumpPage(
        tester,
        transactions: [
          makeTx('e1', purpose: 'ランチ', category: '食費'),
          makeTx('e2', purpose: 'バス', category: '交通費'),
          makeTx('i1', amount: 50000, purpose: '給与', category: '収入'),
          makeTx('i2', amount: 3000, purpose: '副業', category: '収入'),
        ],
        filter: const TransactionFilter(type: TransactionFilterType.expense),
      );

      // 絞込外（収入）は描画されていない
      expect(find.byKey(HistorySelectionKeys.item('i1')), findsNothing);

      await tester.longPress(find.byKey(HistorySelectionKeys.item('e1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(HistorySelectionKeys.selectAll));
      await tester.pumpAndSettle();
      expect(find.text('2件選択'), findsOneWidget);

      await tester.tap(find.byKey(HistorySelectionKeys.deleteButton));
      await tester.pumpAndSettle();
      expect(find.text('選択した 2件を削除します。取り消せます。'), findsOneWidget);
      await tester.tap(find.byKey(HistorySelectionKeys.confirmDelete));
      await tester.pumpAndSettle();

      expect(
        controller.deleteCalls.map((tx) => tx.id).toList(),
        <String>['e1', 'e2'],
      );
      // 絞込外の収入取引は 1 件も削除されていない
      expect(
        controller.deleteCalls.any((tx) => tx.id == 'i1' || tx.id == 'i2'),
        isFalse,
      );
      expect(controller.transactions.length, 2);
      expect(
        controller.transactions.map((tx) => tx.id).toSet(),
        <String>{'i1', 'i2'},
      );
    });

    testWidgets('選択後に絞込が変わっても絞込外になった選択は削除しない', (tester) async {
      final controller = await pumpPage(tester, transactions: threeTx());

      // a と b を選択（この時点では両方表示中）
      await tester.longPress(find.byKey(HistorySelectionKeys.item('a')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(HistorySelectionKeys.item('b')));
      await tester.pumpAndSettle();
      expect(find.text('2件選択'), findsOneWidget);

      // 絞込を「食費」に変更 → b（交通費）が非表示になる
      controller.updateFilter(
        const TransactionFilter(categories: <String>{'食費'}),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(HistorySelectionKeys.item('b')), findsNothing);

      await tester.tap(find.byKey(HistorySelectionKeys.deleteButton));
      await tester.pumpAndSettle();
      // 表示集合と照合するため削除対象は 1 件になる
      expect(find.text('選択した 1件を削除します。取り消せます。'), findsOneWidget);
      await tester.tap(find.byKey(HistorySelectionKeys.confirmDelete));
      await tester.pumpAndSettle();

      expect(controller.deleteCalls.map((tx) => tx.id).toList(), <String>['a']);
      expect(controller.transactions.map((tx) => tx.id).toSet(),
          <String>{'b', 'c'});
    });
  });

  group('Undo', () {
    testWidgets('Undo で削除した全件が元順序で復元される', (tester) async {
      final controller = await pumpPage(tester, transactions: threeTx());

      await tester.longPress(find.byKey(HistorySelectionKeys.item('a')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(HistorySelectionKeys.item('b')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(HistorySelectionKeys.item('c')));
      await tester.pumpAndSettle();
      expect(find.text('3件選択'), findsOneWidget);

      await tester.tap(find.byKey(HistorySelectionKeys.deleteButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(HistorySelectionKeys.confirmDelete));
      await tester.pumpAndSettle();
      expect(controller.deleteCalls.length, 3);

      // Undo 実行
      await tester.tap(find.byKey(undoActionKey));
      await tester.pumpAndSettle();

      expect(controller.restoredIds, <String>['a', 'b', 'c']);
    });
  });

  group('従来挙動の維持', () {
    testWidgets('選択モードでないタップは従来通りタグ付け導線を呼ぶ', (tester) async {
      await pumpPage(tester, transactions: threeTx());

      await tester.tap(find.byKey(HistorySelectionKeys.item('a')));
      await tester.pumpAndSettle();

      // タグ定義が空のためタグ付け案内が出る（＝タグ付け導線が呼ばれた）
      expect(
        find.text('タグがありません。タグ管理から作成してください。'),
        findsOneWidget,
      );
      // 選択モードには入っていない
      expect(find.text('1件選択'), findsNothing);
      expect(find.byKey(HistorySelectionKeys.checkbox('a')), findsNothing);
    });

    testWidgets('選択モード中のタップはタグ付けを発火させない', (tester) async {
      await pumpPage(tester, transactions: threeTx());

      await tester.longPress(find.byKey(HistorySelectionKeys.item('a')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(HistorySelectionKeys.item('b')));
      await tester.pumpAndSettle();

      expect(
        find.text('タグがありません。タグ管理から作成してください。'),
        findsNothing,
      );
      expect(find.text('2件選択'), findsOneWidget);
    });

    testWidgets('従来の単件削除メニューは選択モード外で従来通り動作する', (tester) async {
      final controller = await pumpPage(tester, transactions: threeTx());

      // 訂正メニューを開いて削除を選ぶ（従来の単件削除導線）
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('削除').last);
      await tester.pumpAndSettle();

      // 単件削除の確認ダイアログ（一括削除とは別文言）
      expect(find.text('取引を削除'), findsOneWidget);
      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();

      expect(controller.deleteCalls, isEmpty);
      expect(find.text('取引履歴'), findsOneWidget);
    });
  });
}
