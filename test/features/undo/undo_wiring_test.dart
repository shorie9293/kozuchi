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

/// 取引削除 → Undo スナックバー → 元に戻す で取引が復元されるまでの配線試練。
///
/// 注意:
/// - WashiBackground 等の repeat アニメーション対策で pumpAndSettle は使わず、
///   pump() + pump(Duration) で進める。
/// - タグ読み込みが SharedPreferences を参照するため setUp でモック初期化する。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// 2026-06-15 の支出1件を持つリポジトリとコントローラを組み立てる。
  Future<(InMemoryExpenseRepository, TransactionController)> buildSut() async {
    final repo = InMemoryExpenseRepository();
    await repo.saveEntry(
      ExpenseEntry(
        id: 'e1',
        amount: 3000,
        category: '食費',
        date: DateTime(2026, 6, 15, 12, 0),
        note: 'コンビニ',
      ),
    );
    final controller = TransactionController(
      expenseRepository: repo,
      initialFilter: TransactionFilter(
        type: TransactionFilterType.all,
        startDate: DateTime(2026, 6, 1),
        endDate: DateTime(2026, 6, 15),
      ),
    );
    return (repo, controller);
  }

  Future<void> pumpPage(
    WidgetTester tester,
    TransactionController controller,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TransactionHistoryPage(
          controller: controller,
          clock: () => DateTime(2026, 6, 15, 18, 0),
        ),
      ),
    );
    // 初回ロード（fetchTransactions + タグ読み込み）を進める
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// 訂正メニュー（⋮）→「削除」→ 確認ダイアログ「削除する」まで進める。
  Future<void> deleteFirstTransaction(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('削除').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(TransactionEditAppKeys.deleteConfirmButton),
      findsOneWidget,
      reason: '既存の確認ダイアログが維持されている',
    );
    await tester.tap(find.byKey(TransactionEditAppKeys.deleteConfirmButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('取引削除のUndo配線', () {
    testWidgets('削除→SnackBar表示→元に戻す→取引が復元される', (tester) async {
      final (repo, controller) = await buildSut();
      addTearDown(controller.dispose);

      await pumpPage(tester, controller);
      expect(find.text('コンビニ'), findsOneWidget);

      await deleteFirstTransaction(tester);

      // 削除は即時実行のまま（既存挙動を変えない）
      expect(await repo.getEntryCount(), 0);
      expect(find.text('コンビニ'), findsNothing);

      // Undo スナックバー（文言・アクション）
      expect(find.text('取引を削除しました'), findsOneWidget);
      expect(find.text('元に戻す'), findsOneWidget);
      expect(find.byKey(undoActionKey), findsOneWidget);

      await tester.tap(find.byKey(undoActionKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // リポジトリへ復元され、画面にも戻る
      expect(await repo.getEntryCount(), 1);
      final restored = await repo.getEntryById('e1');
      expect(restored, isNotNull);
      expect(restored!.amount, 3000);
      expect(restored.category, '食費');
      expect(restored.note, 'コンビニ');
      expect(find.text('コンビニ'), findsOneWidget);
    });

    testWidgets('「元に戻す」は一度きり（二重復元しない）', (tester) async {
      final (repo, controller) = await buildSut();
      addTearDown(controller.dispose);

      await pumpPage(tester, controller);
      await deleteFirstTransaction(tester);

      await tester.tap(find.byKey(undoActionKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(await repo.getEntryCount(), 1);
      expect(find.byKey(undoActionKey), findsNothing);
    });

    testWidgets('削除しなければ SnackBar は出ない（確認ダイアログ取消）', (tester) async {
      final (repo, controller) = await buildSut();
      addTearDown(controller.dispose);

      await pumpPage(tester, controller);

      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('削除').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(TransactionEditAppKeys.deleteCancelButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(await repo.getEntryCount(), 1);
      expect(find.byKey(undoActionKey), findsNothing);
      expect(find.text('コンビニ'), findsOneWidget);
    });
  });
}
