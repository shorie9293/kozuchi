import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/features/recurring_transaction/data/recurring_transaction_repository.dart';
import 'package:kozuchi/features/recurring_transaction/presentation/screens/recurring_transaction_screen.dart';

/// 破損時に画面が「定期取引はまだありません」とだけ言って黙らないことの試練。
///
/// 旧実装は破損を空リストとして描画し、利用者には「登録していない」と
/// しか見えなかった。さらに追加ボタンを押すと既存定義が恒久消失した。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const defsKey = 'kozuchi_recurring_defs';
  const corruptRaw = '[{"id":"rent","amount":"文字列"}, "壊れた要素"]';

  late RecurringTransactionRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = const RecurringTransactionRepository();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: RecurringTransactionScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
  }

  group('RecurringTransactionScreen - 破損データの可視化', () {
    testWidgets('破損時は警告と退避導線を表示する', (tester) async {
      SharedPreferences.setMockInitialValues({defsKey: corruptRaw});

      await pumpScreen(tester);

      expect(find.textContaining('保存データが壊れています'), findsWidgets);
      expect(find.byKey(const Key('recurringTx_archiveCorrupt')), findsOneWidget);
    });

    testWidgets('正常時は警告を出さない（回帰）', (tester) async {
      await pumpScreen(tester);

      expect(find.byKey(const Key('recurringTx_archiveCorrupt')), findsNothing);
      expect(find.text('定期取引はまだありません'), findsOneWidget);
    });

    testWidgets('退避ボタンで破損データを退避し、警告が消えて新規登録できる', (tester) async {
      SharedPreferences.setMockInitialValues({defsKey: corruptRaw});
      await pumpScreen(tester);

      await tester.tap(find.byKey(const Key('recurringTx_archiveCorrupt')));
      await tester.pumpAndSettle();

      // 警告が消える
      expect(find.byKey(const Key('recurringTx_archiveCorrupt')), findsNothing);
      // 元データは退避キーに残る
      final p = await SharedPreferences.getInstance();
      expect(p.getString(defsKey), isNull);
      expect(
        p.getKeys().where((k) => k.startsWith('kozuchi_recurring_backup_')),
        isNotEmpty,
      );

      // 以後は通常の追加が通る
      await tester.tap(find.text('定期取引を追加'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('recurringTx_purposeField')), '家賃');
      await tester.enterText(
          find.byKey(const Key('recurringTx_amountField')), '-85000');
      await tester.tap(find.byKey(const Key('recurringTx_saveButton')));
      await tester.pumpAndSettle();

      final defs = await repository.loadDefinitions();
      expect(defs, hasLength(1));
      expect(defs[0].purpose, '家賃');
    });

    testWidgets('破損状態のまま追加しようとすると理由を表示し、保存しない', (tester) async {
      SharedPreferences.setMockInitialValues({defsKey: corruptRaw});
      await pumpScreen(tester);

      await tester.tap(find.text('定期取引を追加'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('recurringTx_purposeField')), '給与');
      await tester.enterText(
          find.byKey(const Key('recurringTx_amountField')), '300000');
      await tester.tap(find.byKey(const Key('recurringTx_saveButton')));
      await tester.pumpAndSettle();

      // 理由が画面に出る（無言で消えない）
      expect(find.textContaining('破損'), findsWidgets);
      // 元データは1バイトも変わらない
      final p = await SharedPreferences.getInstance();
      expect(p.getString(defsKey), corruptRaw);
    });
  });
}
