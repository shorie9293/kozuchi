import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/features/wallet/domain/models/wallet.dart';
import 'package:kozuchi/features/wallet/domain/models/wallet_movement.dart';
import 'package:kozuchi/features/wallet/domain/wallet_service.dart';

void main() {
  const cash = Wallet(id: 'w1', name: '現金', initialBalance: 10000);
  const bank = Wallet(
    id: 'w2',
    name: '銀行',
    type: WalletType.bank,
    initialBalance: 200000,
  );
  const card = Wallet(
    id: 'w3',
    name: 'カード',
    type: WalletType.credit,
    initialBalance: 0,
  );

  WalletMovement m(
    String id,
    String walletId,
    int amount, {
    DateTime? date,
  }) =>
      WalletMovement(
        id: id,
        walletId: walletId,
        amount: amount,
        date: date ?? DateTime(2026, 9, 1),
      );

  group('WalletService.compute', () {
    test('財布が無ければ空の集計', () {
      final summary = WalletService.compute(wallets: const [], movements: const []);
      expect(summary.isEmpty, isTrue);
      expect(summary.totalBalance, 0);
      expect(summary.balances, isEmpty);
    });

    test('初期残高のみのとき入出金は0で残高は初期値', () {
      final summary = WalletService.compute(
        wallets: const [cash, bank],
        movements: const [],
      );
      expect(summary.totalBalance, 210000);
      final cashBalance = summary.balanceOf('w1')!;
      expect(cashBalance.income, 0);
      expect(cashBalance.expense, 0);
      expect(cashBalance.balance, 10000);
      expect(cashBalance.isEmpty, isTrue);
    });

    test('入金と出金を財布別に集計する', () {
      final summary = WalletService.compute(
        wallets: const [cash, bank],
        movements: [
          m('m1', 'w1', 5000),
          m('m2', 'w1', -1200),
          m('m3', 'w1', -800),
          m('m4', 'w2', 30000),
        ],
      );
      final cashBalance = summary.balanceOf('w1')!;
      expect(cashBalance.income, 5000);
      expect(cashBalance.expense, 2000);
      expect(cashBalance.netChange, 3000);
      expect(cashBalance.balance, 13000);
      expect(summary.balanceOf('w2')!.balance, 230000);
      expect(summary.totalIncome, 35000);
      expect(summary.totalExpense, 2000);
      expect(summary.totalBalance, 243000);
    });

    test('未所有の財布IDを持つログは無視する', () {
      final summary = WalletService.compute(
        wallets: const [cash],
        movements: [m('m1', 'w1', 1000), m('m2', 'ghost', -99999)],
      );
      expect(summary.totalIncome, 1000);
      expect(summary.totalExpense, 0);
      expect(summary.totalBalance, 11000);
      expect(summary.balanceOf('ghost'), isNull);
    });

    test('残高降順・同額はID昇順で並ぶ', () {
      const a = Wallet(id: 'b', name: 'B', initialBalance: 100);
      const b = Wallet(id: 'a', name: 'A', initialBalance: 100);
      const c = Wallet(id: 'c', name: 'C', initialBalance: 500);
      final summary = WalletService.compute(
        wallets: const [a, b, c],
        movements: const [],
      );
      expect(summary.balances.map((e) => e.wallet.id).toList(), ['c', 'a', 'b']);
    });

    test('クレジットは残高マイナスになり得て警告対象になる', () {
      final summary = WalletService.compute(
        wallets: const [card, cash],
        movements: [m('m1', 'w3', -5000)],
      );
      final cardBalance = summary.balanceOf('w3')!;
      expect(cardBalance.balance, -5000);
      expect(cardBalance.isNegative, isTrue);
      expect(summary.negativeWallets.map((e) => e.wallet.id).toList(), ['w3']);
      expect(summary.totalBalance, 5000);
    });

    test('種別ごとの合計残高を返す（金額0の種別も含む）', () {
      final summary = WalletService.compute(
        wallets: const [cash, bank, card],
        movements: [m('m1', 'w3', -1000)],
      );
      final totals = summary.totalsByType;
      expect(totals[WalletType.cash], 10000);
      expect(totals[WalletType.bank], 200000);
      expect(totals[WalletType.credit], -1000);
      expect(totals[WalletType.emoney], 0);
      expect(summary.totalBalanceOfType(WalletType.bank), 200000);
    });

    test('財布1件でも入出金が反映される', () {
      final summary = WalletService.compute(
        wallets: const [cash],
        movements: [m('m1', 'w1', 500)],
      );
      expect(summary.totalBalance, 10500);
    });
  });

  group('WalletService.movementsFor', () {
    final movements = [
      WalletMovement(
        id: 'm2',
        walletId: 'w1',
        amount: 100,
        date: DateTime(2026, 9, 2),
      ),
      WalletMovement(
        id: 'm1',
        walletId: 'w1',
        amount: -200,
        date: DateTime(2026, 9, 1),
      ),
      WalletMovement(
        id: 'm3',
        walletId: 'w2',
        amount: 300,
        date: DateTime(2026, 9, 3),
      ),
    ];

    test('新しい順で対象財布のみを返す', () {
      final result = WalletService.movementsFor(movements, 'w1');
      expect(result.map((e) => e.id).toList(), ['m2', 'm1']);
    });

    test('空の財布IDでは空を返す', () {
      expect(WalletService.movementsFor(movements, ''), isEmpty);
    });
  });
}
