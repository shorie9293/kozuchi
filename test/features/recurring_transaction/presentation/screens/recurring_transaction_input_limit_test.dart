import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/core/input/input_limits.dart';
import 'package:kozuchi/features/recurring_transaction/data/recurring_transaction_repository.dart';
import 'package:kozuchi/features/recurring_transaction/presentation/screens/recurring_transaction_screen.dart';
import 'package:kozuchi/features/shared/presentation/kozuchi_app_keys.dart';

/// 入力欄の長さ上限が「保存時に切り捨て・破損しない」ことを撃つ試練。
///
/// kozuchi は取引を 1 本の JSON 文字列へ保存するため、無制限入力は
/// 保存肥大・破損に直結する。上限超過の長文を入れても、
/// 先頭 N 文字がそのまま保存され、再読込で例外も全損も起きないことを確かめる。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const repository = RecurringTransactionRepository();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> openAddDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
          home: RecurringTransactionScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('定期取引を追加'));
    await tester.pumpAndSettle();
  }

  group('入力上限（定期取引）', () {
    testWidgets('上限超過の用途・金額は上限で切り捨てられ、保存→再読込で先頭N文字が保持される', (tester) async {
      // 用途の上限（100）を大きく超える長文。金額は 9 桁を超える数字列。
      final longPurpose = 'あ' * 250;
      final longAmount = '1234567890123';

      await openAddDialog(tester);

      await tester.enterText(
        find.byKey(KozuchiAppKeys.recurringTx_purposeField),
        longPurpose,
      );
      await tester.enterText(
        find.byKey(KozuchiAppKeys.recurringTx_amountField),
        longAmount,
      );
      await tester.pump();

      await tester.tap(find.byKey(KozuchiAppKeys.recurringTx_saveButton));
      await tester.pumpAndSettle();

      // 検証エラーでダイアログが残らない = 保存経路が例外で止まっていない。
      expect(find.byType(AlertDialog), findsNothing);

      // 再読込（保存済み JSON の再パース）で例外なく読める = 破損していない。
      final defs = await repository.loadDefinitions();
      expect(defs, hasLength(1));
      expect(defs[0].purpose.length, InputLimits.labelMaxLength);
      expect(
        defs[0].purpose,
        longPurpose.substring(0, InputLimits.labelMaxLength),
      );
      expect(defs[0].amount, 123456789);

      // 保存領域そのものが壊れていないことを JSON としても確かめる。
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('kozuchi_recurring_defs');
      expect(raw, isNotNull);
      expect(() => jsonDecode(raw!), returnsNormally);
    });

    testWidgets('上限内の入力は切り捨てられない', (tester) async {
      const purpose = '家賃';
      const amount = '85000';

      await openAddDialog(tester);

      await tester.enterText(
        find.byKey(KozuchiAppKeys.recurringTx_purposeField),
        purpose,
      );
      await tester.enterText(
        find.byKey(KozuchiAppKeys.recurringTx_amountField),
        amount,
      );
      await tester.tap(find.byKey(KozuchiAppKeys.recurringTx_saveButton));
      await tester.pumpAndSettle();

      final defs = await repository.loadDefinitions();
      expect(defs, hasLength(1));
      expect(defs[0].purpose, purpose);
      expect(defs[0].amount, 85000);
    });
  });
}
