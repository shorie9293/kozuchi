import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kozuchi/features/wallet/data/wallet_repository.dart';
import 'package:kozuchi/features/wallet/domain/models/wallet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const repository = WalletRepository();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('WalletRepository 財布', () {
    test('未保存時は空リスト', () async {
      expect(await repository.loadWallets(), isEmpty);
    });

    test('追加した財布を読み出せる', () async {
      await repository.addWallet(
        name: 'みずほ銀行',
        type: WalletType.bank,
        initialBalance: 250000,
        id: 'w1',
      );
      final wallets = await repository.loadWallets();
      expect(wallets.single.id, 'w1');
      expect(wallets.single.name, 'みずほ銀行');
      expect(wallets.single.type, WalletType.bank);
      expect(wallets.single.initialBalance, 250000);
    });

    test('名前の前後空白は除去される', () async {
      await repository.addWallet(name: '  現金  ', id: 'w1');
      expect((await repository.loadWallets()).single.name, '現金');
    });

    test('空の名前は ArgumentError', () async {
      expect(
        () => repository.addWallet(name: '   ', id: 'w1'),
        throwsArgumentError,
      );
    });

    test('負の初期残高は ArgumentError', () async {
      expect(
        () => repository.addWallet(name: '現金', initialBalance: -1, id: 'w1'),
        throwsArgumentError,
      );
    });

    test('同一IDは置換される', () async {
      await repository.addWallet(name: '現金', id: 'w1');
      await repository.addWallet(name: '財布', id: 'w1');
      final wallets = await repository.loadWallets();
      expect(wallets.length, 1);
      expect(wallets.single.name, '財布');
    });

    test('改名できる', () async {
      await repository.addWallet(name: '現金', id: 'w1');
      final updated = await repository.renameWallet('w1', ' お財布 ');
      expect(updated.single.name, 'お財布');
    });

    test('存在しないIDの改名は何も変えない', () async {
      await repository.addWallet(name: '現金', id: 'w1');
      final updated = await repository.renameWallet('ghost', 'X');
      expect(updated.single.name, '現金');
    });

    test('削除で財布が消える', () async {
      await repository.addWallet(name: '現金', id: 'w1');
      await repository.addWallet(name: '銀行', id: 'w2');
      final updated = await repository.removeWallet('w1');
      expect(updated.map((w) => w.id).toList(), ['w2']);
    });

    test('削除時にその財布の入出金ログも消える', () async {
      await repository.addWallet(name: '現金', id: 'w1');
      await repository.addWallet(name: '銀行', id: 'w2');
      await repository.addMovement(
        walletId: 'w1',
        amount: -500,
        date: DateTime(2026, 9, 1),
        id: 'm1',
      );
      await repository.addMovement(
        walletId: 'w2',
        amount: 1000,
        date: DateTime(2026, 9, 1),
        id: 'm2',
      );

      await repository.removeWallet('w1');

      final movements = await repository.loadMovements();
      expect(movements.map((m) => m.id).toList(), ['m2']);
    });

    test('破損JSONは空リストに落ちる', () async {
      SharedPreferences.setMockInitialValues({
        WalletRepository.walletsKey: 'not-json',
      });
      expect(await repository.loadWallets(), isEmpty);
    });
  });

  group('WalletRepository 入出金ログ', () {
    test('未保存時は空リスト', () async {
      expect(await repository.loadMovements(), isEmpty);
    });

    test('追加した入出金を読み出せる', () async {
      await repository.addMovement(
        walletId: 'w1',
        amount: 5000,
        note: ' ATM入金 ',
        date: DateTime(2026, 9, 10),
        id: 'm1',
      );
      final movements = await repository.loadMovements();
      expect(movements.single.id, 'm1');
      expect(movements.single.walletId, 'w1');
      expect(movements.single.amount, 5000);
      expect(movements.single.note, 'ATM入金');
      expect(movements.single.date, DateTime(2026, 9, 10));
    });

    test('金額0は ArgumentError', () async {
      expect(
        () => repository.addMovement(
          walletId: 'w1',
          amount: 0,
          date: DateTime(2026, 9, 10),
        ),
        throwsArgumentError,
      );
    });

    test('空の財布IDは ArgumentError', () async {
      expect(
        () => repository.addMovement(
          walletId: '  ',
          amount: 100,
          date: DateTime(2026, 9, 10),
        ),
        throwsArgumentError,
      );
    });

    test('削除でログが消える', () async {
      await repository.addMovement(
        walletId: 'w1',
        amount: 100,
        date: DateTime(2026, 9, 10),
        id: 'm1',
      );
      await repository.addMovement(
        walletId: 'w1',
        amount: -100,
        date: DateTime(2026, 9, 11),
        id: 'm2',
      );
      final updated = await repository.removeMovement('m1');
      expect(updated.map((m) => m.id).toList(), ['m2']);
    });

    test('movementsFor は対象財布のみを新しい順で返す', () async {
      await repository.addMovement(
        walletId: 'w1',
        amount: 100,
        date: DateTime(2026, 9, 1),
        id: 'm1',
      );
      await repository.addMovement(
        walletId: 'w1',
        amount: -200,
        date: DateTime(2026, 9, 5),
        id: 'm2',
      );
      await repository.addMovement(
        walletId: 'w2',
        amount: 300,
        date: DateTime(2026, 9, 9),
        id: 'm3',
      );

      final result = await repository.movementsFor('w1');
      expect(result.map((m) => m.id).toList(), ['m2', 'm1']);
    });

    test('金額0の破損レコードは読み飛ばす', () async {
      SharedPreferences.setMockInitialValues({
        WalletRepository.movementsKey:
            '[{"id":"m1","walletId":"w1","amount":0,"date":"2026-09-01"},'
                '{"id":"m2","walletId":"w1","amount":100,"date":"2026-09-01"}]',
      });
      final movements = await repository.loadMovements();
      expect(movements.map((m) => m.id).toList(), ['m2']);
    });
  });
}
