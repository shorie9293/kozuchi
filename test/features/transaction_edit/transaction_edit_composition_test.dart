import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/domain/services/expense_repository_impl.dart';
import 'package:kozuchi/features/transaction_edit/presentation/transaction_edit_app_keys.dart';
import 'package:kozuchi/features/transaction_history/presentation/screens/transaction_history_page.dart';
import 'package:kozuchi/features/transaction_history/presentation/state/transaction_controller.dart';

/// 「画面（⋮メニュー）→ コントローラ → リポジトリ → 再表示」の合成の不変条件を撃つ。
void main() {
  testWidgets('削除: ⋮メニュー → 確認ダイアログ → リポジトリ削除 → 一覧から消える',
      (tester) async {
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day, 9);
    final repo = InMemoryExpenseRepository();
    await repo.saveEntries([
      ExpenseEntry(id: 'a', amount: 100, category: '食費', date: day),
      ExpenseEntry(id: 'b', amount: 200, category: '交通費', date: day),
    ]);
    final controller = TransactionController(expenseRepository: repo);

    await tester.pumpWidget(
      MaterialApp(home: TransactionHistoryPage(controller: controller)),
    );
    // タグ読込などの非同期を進める
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('-¥100'), findsOneWidget);
    expect(find.text('-¥200'), findsOneWidget);

    // b の訂正メニューを開いて削除を選択
    await tester.tap(find.byKey(TransactionEditAppKeys.menuFor(
      DateTime(day.year, day.month, day.day, 9).toIso8601String(),
      -200,
    )).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除'));
    await tester.pumpAndSettle();
    // 確認ダイアログ
    await tester.tap(find.byKey(TransactionEditAppKeys.deleteConfirmButton));
    await tester.pumpAndSettle();

    expect(find.text('-¥200'), findsNothing);
    expect(find.text('-¥100'), findsOneWidget);
    expect(await repo.getEntryCount(), 1);
    expect(controller.transactions.single.id, 'a');
    controller.dispose();
  });

  testWidgets('編集: ⋮メニュー → ダイアログ保存 → 一覧に反映され、リポジトリに永続化される',
      (tester) async {
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day, 9);
    final repo = InMemoryExpenseRepository();
    await repo.saveEntry(
      ExpenseEntry(
        id: 'a',
        amount: 100,
        category: '食費',
        date: day,
        note: '昼食',
      ),
    );
    final controller = TransactionController(expenseRepository: repo);

    await tester.pumpWidget(
      MaterialApp(home: TransactionHistoryPage(controller: controller)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('-¥100'), findsOneWidget);

    await tester.tap(find.byKey(TransactionEditAppKeys.menuFor(
      DateTime(day.year, day.month, day.day, 9).toIso8601String(),
      -100,
    )).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('編集'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(TransactionEditAppKeys.amountField), '300');
    await tester.enterText(find.byKey(TransactionEditAppKeys.categoryField), '娯楽');
    await tester.enterText(find.byKey(TransactionEditAppKeys.noteField), '書籍');
    await tester.tap(find.byKey(TransactionEditAppKeys.saveButton));
    await tester.pumpAndSettle();

    expect(find.text('-¥300'), findsOneWidget);
    expect(find.text('-¥100'), findsNothing);
    final saved = await repo.getEntryById('a');
    expect(saved!.amount, 300);
    expect(saved.category, '娯楽');
    expect(saved.note, '書籍');
    // SnackBar の案内
    expect(find.text('取引を更新しました'), findsOneWidget);
    controller.dispose();
  });
}
