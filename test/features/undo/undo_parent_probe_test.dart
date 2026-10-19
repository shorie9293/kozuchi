// 親探針: kozuchi 削除Undoの合成不変条件。
//
// 1) 復元後もバッファが再利用できる（2件目を削除して再度Undoできるか）。
// 2) 復元で同一idが二重登録されない（件数が増えない）。
// 3) レシート画像パスが復元で失われない。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/domain/services/expense_repository_impl.dart';
import 'package:kozuchi/features/transaction_edit/presentation/transaction_edit_app_keys.dart';
import 'package:kozuchi/features/transaction_filter/domain/models/transaction_filter.dart';
import 'package:kozuchi/features/transaction_history/presentation/screens/transaction_history_page.dart';
import 'package:kozuchi/features/transaction_history/presentation/state/transaction_controller.dart';
import 'package:kozuchi/features/undo/presentation/undo_snack_bar.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('親探針: Undo後に別の取引も削除→Undoでき、二重登録も起きない', (tester) async {
    final repo = InMemoryExpenseRepository();
    await repo.saveEntry(ExpenseEntry(
      id: 'e1',
      amount: 3000,
      category: '食費',
      date: DateTime(2026, 6, 15, 12, 0),
      note: 'コンビニ',
      receiptImagePath: '/tmp/receipt_a.jpg',
    ));
    await repo.saveEntry(ExpenseEntry(
      id: 'e2',
      amount: 800,
      category: '交通費',
      date: DateTime(2026, 6, 14, 9, 0),
      note: 'バス',
    ));
    final controller = TransactionController(
      expenseRepository: repo,
      initialFilter: TransactionFilter(
        type: TransactionFilterType.all,
        startDate: DateTime(2026, 6, 1),
        endDate: DateTime(2026, 6, 15),
      ),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: TransactionHistoryPage(
        controller: controller,
        clock: () => DateTime(2026, 6, 15, 18, 0),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    Future<void> deleteTop() async {
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('削除').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(TransactionEditAppKeys.deleteConfirmButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    // 1件目（一覧先頭＝6/15 の e1）を削除 → Undo
    await deleteTop();
    expect(await repo.getEntryCount(), 1);
    await tester.tap(find.byKey(undoActionKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(await repo.getEntryCount(), 2, reason: 'Undoで重複登録された/復元されていない');
    final restored1 = await repo.getEntryById('e1');
    expect(restored1!.receiptImagePath, '/tmp/receipt_a.jpg',
        reason: 'レシート画像パスが復元で失われた');

    // 2件目（もう一方）を削除 → 再度 Undo（バッファ再利用）
    await tester.tap(find.byIcon(Icons.more_vert).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('削除').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(TransactionEditAppKeys.deleteConfirmButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(await repo.getEntryCount(), 1);

    final undoAction = find.byKey(undoActionKey);
    expect(undoAction, findsOneWidget, reason: '2回目の削除でUndoが出ない');
    await tester.tap(undoAction);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(await repo.getEntryCount(), 2, reason: '2回目のUndoが復元しない/二重登録');
  });
}
