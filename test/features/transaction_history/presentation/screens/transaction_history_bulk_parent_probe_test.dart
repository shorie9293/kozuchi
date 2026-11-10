import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/transaction_filter/domain/models/transaction_filter.dart';
import 'package:kozuchi/features/transaction_history/presentation/screens/transaction_history_page.dart';
import 'package:kozuchi/features/transaction_history/presentation/state/transaction_controller.dart';
import 'package:kozuchi/features/transaction_history/presentation/widgets/transaction_list_item.dart';

/// 親探針専用のフェイク。子の試練とは独立に、削除の成否を
/// ID 単位で制御できるようにする（部分失敗の再現のため）。
class ProbeController extends TransactionController {
  ProbeController({required List<TransactionModel> transactions})
      : _transactions = List<TransactionModel>.of(transactions);

  final List<TransactionModel> _transactions;
  TransactionFilter _filter = const TransactionFilter();

  final List<String?> deleteCalls = <String?>[];
  final List<String?> restoredIds = <String?>[];

  /// この ID の削除だけ失敗させる。
  final Set<String?> failIds = <String?>{};

  /// この ID の削除だけ例外を投げる。
  final Set<String?> throwIds = <String?>{};

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
    deleteCalls.add(transaction.id);
    if (throwIds.contains(transaction.id)) {
      throw StateError('probe: delete boom');
    }
    if (failIds.contains(transaction.id)) return false;
    _transactions.removeWhere((tx) => tx.id == transaction.id);
    return true;
  }

  /// 同期・再読込などで取引が表示集合から消えたことを再現する。
  void removeSilently(String id) {
    _transactions.removeWhere((tx) => tx.id == id);
    notifyListeners();
  }

  @override
  Future<bool> restoreTransaction(TransactionModel transaction) async {
    restoredIds.add(transaction.id);
    return true;
  }
}

TransactionModel tx(String id, {int amount = -1000, String category = '食費'}) {
  return TransactionModel(
    id: id,
    amount: amount,
    purpose: 'ランチ',
    category: category,
    datetime: '2026-06-15T12:00:00',
  );
}

Future<ProbeController> pumpPage(
  WidgetTester tester,
  List<TransactionModel> transactions,
) async {
  final controller = ProbeController(transactions: transactions);
  await tester.pumpWidget(
    MaterialApp(home: TransactionHistoryPage(controller: controller)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return controller;
}

/// 長押しで選択モードに入り、全選択して削除を確定する。
Future<void> selectAllAndDelete(WidgetTester tester) async {
  await tester.tap(find.byKey(HistorySelectionKeys.selectAll));
  await tester.pump();
  await tester.tap(find.byKey(HistorySelectionKeys.deleteButton));
  await tester.pump();
  await tester.tap(find.byKey(HistorySelectionKeys.confirmDelete));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ── 親探針1: 部分失敗時、成功分だけが元順序で Undo 復元される ──
  testWidgets('親探針: 部分失敗でも成功分だけが元順序で Undo 復元される', (tester) async {
    final controller = await pumpPage(
      tester,
      [tx('a'), tx('b'), tx('c')],
    );
    controller.failIds.add('b');

    await tester.longPress(find.byKey(HistorySelectionKeys.item('a')));
    await tester.pump();
    await selectAllAndDelete(tester);

    // 3件すべてに削除要求が飛ぶが、b だけ失敗する。
    expect(controller.deleteCalls, ['a', 'b', 'c']);
    expect(find.textContaining('2件を削除しました'), findsOneWidget);
    expect(find.textContaining('1件は失敗'), findsOneWidget);

    // Undo は成功分（a, c）を元順序で復元する。失敗した b は復元対象外。
    await tester.tap(find.text('元に戻す'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.restoredIds, ['a', 'c']);
  });

  // ── 親探針2: deleteOne が例外を投げても画面は壊れず、残りを継続する ──
  testWidgets('親探針: 途中の削除が例外を投げても残りを削除し画面が壊れない', (tester) async {
    final controller = await pumpPage(tester, [tx('x'), tx('y'), tx('z')]);
    controller.throwIds.add('y');

    await tester.longPress(find.byKey(HistorySelectionKeys.item('x')));
    await tester.pump();
    await selectAllAndDelete(tester);

    expect(tester.takeException(), isNull);
    expect(controller.deleteCalls, ['x', 'y', 'z']);
    expect(find.textContaining('2件を削除しました'), findsOneWidget);
    // 例外を投げた y は残り、成功した x/z は消えている。
    expect(controller.transactions.map((t) => t.id), ['y']);
  });

  // ── 親探針3: 選択した ID が表示集合から外れたら削除しない（unknown 退避） ──
  testWidgets('親探針: 選択後に表示から消えた取引は削除対象にならない', (tester) async {
    final controller = await pumpPage(
      tester,
      [tx('keep', category: '食費'), tx('gone', category: '食費')],
    );

    await tester.longPress(find.byKey(HistorySelectionKeys.item('keep')));
    await tester.pump();
    await tester.tap(find.byKey(HistorySelectionKeys.selectAll));
    await tester.pump();
    expect(find.text('2件選択'), findsOneWidget);

    // 別経路で 'gone' が消えた（同期・再読込など）ことを再現する。
    controller.removeSilently('gone');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(HistorySelectionKeys.deleteButton));
    await tester.pump();
    // 表示中の1件だけを対象にした確認ダイアログになる。
    expect(find.textContaining('選択した 1件を削除します'), findsOneWidget);
    await tester.tap(find.byKey(HistorySelectionKeys.cancelDelete));
    await tester.pump();
  });

  // ── 親探針4: 全選択 → 解除 → 全選択 の往復で件数が積み上がらない ──
  testWidgets('親探針: 全選択と解除を往復しても選択件数が積み上がらない', (tester) async {
    await pumpPage(tester, [tx('a'), tx('b')]);

    await tester.longPress(find.byKey(HistorySelectionKeys.item('a')));
    await tester.pump();
    await tester.tap(find.byKey(HistorySelectionKeys.selectAll));
    await tester.pump();
    expect(find.text('2件選択'), findsOneWidget);

    await tester.tap(find.byKey(HistorySelectionKeys.clearButton));
    await tester.pump();
    expect(find.text('取引履歴'), findsOneWidget);
    expect(find.byKey(HistorySelectionKeys.deleteButton), findsNothing);

    await tester.longPress(find.byKey(HistorySelectionKeys.item('b')));
    await tester.pump();
    expect(find.text('1件選択'), findsOneWidget);
  });
}
