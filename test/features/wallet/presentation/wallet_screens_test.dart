import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kozuchi/features/wallet/data/wallet_repository.dart';
import 'package:kozuchi/features/wallet/domain/models/wallet.dart';
import 'package:kozuchi/features/wallet/presentation/screens/wallet_management_screen.dart';
import 'package:kozuchi/features/wallet/presentation/screens/wallet_movements_screen.dart';
import 'package:kozuchi/features/wallet/presentation/wallet_app_keys.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const repository = WalletRepository();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpManagement(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: WalletManagementScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpMovements(WidgetTester tester, Wallet wallet) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WalletMovementsScreen(repository: repository, wallet: wallet),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('WalletManagementScreen', () {
    testWidgets('財布が無いときは空状態と合計¥0を表示する', (tester) async {
      await pumpManagement(tester);
      expect(find.byKey(WalletAppKeys.managementScreen), findsOneWidget);
      expect(find.byKey(WalletAppKeys.empty), findsOneWidget);
      expect(find.text('¥0'), findsOneWidget);
    });

    testWidgets('ダイアログから財布を追加できる', (tester) async {
      await pumpManagement(tester);
      await tester.tap(find.byKey(WalletAppKeys.addButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(WalletAppKeys.nameField), 'みずほ銀行');
      await tester.enterText(
        find.byKey(WalletAppKeys.initialField),
        '250000',
      );
      await tester.tap(find.byKey(WalletAppKeys.dialogSaveButton));
      await tester.pumpAndSettle();

      expect(find.byKey(WalletAppKeys.empty), findsNothing);
      expect(find.text('みずほ銀行'), findsOneWidget);
      expect(find.byKey(WalletAppKeys.totalCard), findsOneWidget);
      expect(find.text('¥250,000'), findsWidgets);
      expect((await repository.loadWallets()).single.type, WalletType.cash);
    });

    testWidgets('種別を選択して追加できる', (tester) async {
      await pumpManagement(tester);
      await tester.tap(find.byKey(WalletAppKeys.addButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(WalletAppKeys.nameField), 'Suica');
      await tester.tap(find.byKey(WalletAppKeys.typeDropdown));
      await tester.pumpAndSettle();
      await tester.tap(find.text('電子マネー').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(WalletAppKeys.dialogSaveButton));
      await tester.pumpAndSettle();

      expect((await repository.loadWallets()).single.type, WalletType.emoney);
      expect(find.textContaining('電子マネー'), findsWidgets);
    });

    testWidgets('名前が空ならエラーを表示して保存しない', (tester) async {
      await pumpManagement(tester);
      await tester.tap(find.byKey(WalletAppKeys.addButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(WalletAppKeys.dialogSaveButton));
      await tester.pumpAndSettle();

      expect(find.byKey(WalletAppKeys.dialogError), findsOneWidget);
      expect(await repository.loadWallets(), isEmpty);
    });

    testWidgets('削除ボタンで財布が消える', (tester) async {
      await repository.addWallet(name: '現金', id: 'w1');
      await pumpManagement(tester);
      expect(find.byKey(WalletAppKeys.listTile('w1')), findsOneWidget);

      await tester.tap(find.byKey(WalletAppKeys.deleteButton('w1')));
      await tester.pumpAndSettle();

      expect(find.byKey(WalletAppKeys.listTile('w1')), findsNothing);
      expect(find.byKey(WalletAppKeys.empty), findsOneWidget);
    });

    testWidgets('財布をタップすると入出金画面へ遷移する', (tester) async {
      await repository.addWallet(name: '現金', initialBalance: 1000, id: 'w1');
      await pumpManagement(tester);

      await tester.tap(find.byKey(WalletAppKeys.listTile('w1')));
      await tester.pumpAndSettle();

      expect(find.byKey(WalletAppKeys.movementsScreen), findsOneWidget);
      expect(find.byKey(WalletAppKeys.movementsEmpty), findsOneWidget);
    });
  });

  group('WalletMovementsScreen', () {
    const wallet = Wallet(id: 'w1', name: '現金', initialBalance: 10000);

    testWidgets('残高は初期残高から始まる', (tester) async {
      await pumpMovements(tester, wallet);
      expect(
        tester.widget<Text>(find.byKey(WalletAppKeys.movementsBalance)).data,
        '¥10,000',
      );
    });

    testWidgets('出金を記録すると残高が減る', (tester) async {
      await pumpMovements(tester, wallet);
      await tester.tap(find.byKey(WalletAppKeys.movementAddButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(WalletAppKeys.amountField), '1200');
      await tester.enterText(find.byKey(WalletAppKeys.noteField), 'スーパー');
      await tester.tap(find.byKey(WalletAppKeys.movementSaveButton));
      await tester.pumpAndSettle();

      expect(find.text('スーパー'), findsOneWidget);
      expect(find.text('-¥1,200'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(WalletAppKeys.movementsBalance)).data,
        '¥8,800',
      );
      final saved = await repository.loadMovements();
      expect(saved.single.amount, -1200);
    });

    testWidgets('入金を記録すると残高が増える', (tester) async {
      await pumpMovements(tester, wallet);
      await tester.tap(find.byKey(WalletAppKeys.movementAddButton));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(WalletAppKeys.incomeChoice));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(WalletAppKeys.amountField), '5000');
      await tester.tap(find.byKey(WalletAppKeys.movementSaveButton));
      await tester.pumpAndSettle();

      expect(find.text('+¥5,000'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(WalletAppKeys.movementsBalance)).data,
        '¥15,000',
      );
    });

    testWidgets('金額未入力ではエラーを表示して保存しない', (tester) async {
      await pumpMovements(tester, wallet);
      await tester.tap(find.byKey(WalletAppKeys.movementAddButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(WalletAppKeys.movementSaveButton));
      await tester.pumpAndSettle();

      expect(find.byKey(WalletAppKeys.movementDialogError), findsOneWidget);
      expect(await repository.loadMovements(), isEmpty);
    });

    testWidgets('記録を削除できる', (tester) async {
      await repository.addMovement(
        walletId: 'w1',
        amount: -500,
        note: 'コンビニ',
        date: DateTime(2026, 9, 12),
        id: 'm1',
      );
      await pumpMovements(tester, wallet);
      expect(find.byKey(WalletAppKeys.movementTile('m1')), findsOneWidget);

      await tester.tap(find.byKey(WalletAppKeys.movementDeleteButton('m1')));
      await tester.pumpAndSettle();

      expect(find.byKey(WalletAppKeys.movementTile('m1')), findsNothing);
      expect(find.byKey(WalletAppKeys.movementsEmpty), findsOneWidget);
      expect(await repository.loadMovements(), isEmpty);
    });

    testWidgets('他財布の記録は表示しない', (tester) async {
      await repository.addMovement(
        walletId: 'w2',
        amount: -100,
        date: DateTime(2026, 9, 12),
        id: 'other',
      );
      await pumpMovements(tester, wallet);
      expect(find.byKey(WalletAppKeys.movementTile('other')), findsNothing);
    });
  });
}
