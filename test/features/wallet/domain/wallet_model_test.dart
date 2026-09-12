import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/features/wallet/domain/models/wallet.dart';
import 'package:kozuchi/features/wallet/domain/models/wallet_movement.dart';
import 'package:kozuchi/features/wallet/presentation/wallet_app_keys.dart';

void main() {
  group('WalletType', () {
    test('表示名を持つ', () {
      expect(WalletType.cash.label, '現金');
      expect(WalletType.bank.label, '銀行口座');
      expect(WalletType.emoney.label, '電子マネー');
      expect(WalletType.credit.label, 'クレジット');
    });

    test('文字列から復元し、未知は現金になる', () {
      expect(WalletTypeLabel.parse('bank'), WalletType.bank);
      expect(WalletTypeLabel.parse('unknown'), WalletType.cash);
      expect(WalletTypeLabel.parse(null), WalletType.cash);
      expect(WalletTypeLabel.parse(42), WalletType.cash);
    });
  });

  group('Wallet', () {
    test('既定値は現金・残高0・既定色', () {
      const wallet = Wallet(id: 'w1', name: '現金');
      expect(wallet.type, WalletType.cash);
      expect(wallet.initialBalance, 0);
      expect(wallet.colorValue, Wallet.defaultColorValue);
      expect(wallet.canBeNegative, isFalse);
    });

    test('クレジットのみマイナスになり得る', () {
      const wallet = Wallet(id: 'w1', name: 'カード', type: WalletType.credit);
      expect(wallet.canBeNegative, isTrue);
    });

    test('負の初期残高はアサーション違反', () {
      expect(
        () => Wallet(id: 'w1', name: 'x', initialBalance: -1),
        throwsA(isA<AssertionError>()),
      );
    });

    test('JSON往復で値が保たれる', () {
      const wallet = Wallet(
        id: 'w1',
        name: 'みずほ銀行',
        type: WalletType.bank,
        initialBalance: 250000,
        colorValue: 0xFF112233,
      );
      final restored = Wallet.fromJson(wallet.toJson());
      expect(restored.id, 'w1');
      expect(restored.name, 'みずほ銀行');
      expect(restored.type, WalletType.bank);
      expect(restored.initialBalance, 250000);
      expect(restored.colorValue, 0xFF112233);
    });

    test('破損JSONは安全な既定値に落ちる', () {
      final wallet = Wallet.fromJson(const {});
      expect(wallet.id, '');
      expect(wallet.name, '');
      expect(wallet.type, WalletType.cash);
      expect(wallet.initialBalance, 0);
    });

    test('負の初期残高を持つ破損JSONは0に丸める', () {
      final wallet = Wallet.fromJson(const {'id': 'w1', 'initialBalance': -500});
      expect(wallet.initialBalance, 0);
    });

    test('copyWith はIDを保ったまま一部を差し替える', () {
      const wallet = Wallet(id: 'w1', name: '現金');
      final updated = wallet.copyWith(name: ' 財布 ', type: WalletType.emoney);
      expect(updated.id, 'w1');
      expect(updated.name, ' 財布 ');
      expect(updated.displayName, '財布');
      expect(updated.type, WalletType.emoney);
    });

    test('同一IDなら等価', () {
      const a = Wallet(id: 'w1', name: 'A');
      const b = Wallet(id: 'w1', name: 'B');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });
  });

  group('WalletMovement', () {
    test('符号から入金・出金を判定する', () {
      final income = WalletMovement(
        id: 'm1',
        walletId: 'w1',
        amount: 1000,
        date: DateTime(2026, 9, 13),
      );
      final expense = WalletMovement(
        id: 'm2',
        walletId: 'w1',
        amount: -300,
        date: DateTime(2026, 9, 13),
      );
      expect(income.isIncome, isTrue);
      expect(income.isExpense, isFalse);
      expect(income.incomeAmount, 1000);
      expect(income.expenseAmount, 0);
      expect(expense.isExpense, isTrue);
      expect(expense.expenseAmount, 300);
      expect(expense.incomeAmount, 0);
    });

    test('signed ファクトリは種別に応じた符号を付ける', () {
      final income = WalletMovement.signed(
        id: 'm1',
        walletId: 'w1',
        amount: -500,
        isIncome: true,
        date: DateTime(2026, 9, 13),
      );
      final expense = WalletMovement.signed(
        id: 'm2',
        walletId: 'w1',
        amount: 500,
        isIncome: false,
        date: DateTime(2026, 9, 13),
      );
      expect(income.amount, 500);
      expect(expense.amount, -500);
    });

    test('金額0はアサーション違反', () {
      expect(
        () => WalletMovement(
          id: 'm1',
          walletId: 'w1',
          amount: 0,
          date: DateTime(2026, 9, 13),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('JSON往復で日付と符号が保たれる', () {
      final movement = WalletMovement(
        id: 'm1',
        walletId: 'w1',
        amount: -1200,
        note: 'スーパー',
        date: DateTime(2026, 9, 12, 10, 30),
      );
      final restored = WalletMovement.fromJson(movement.toJson());
      expect(restored.id, 'm1');
      expect(restored.walletId, 'w1');
      expect(restored.amount, -1200);
      expect(restored.note, 'スーパー');
      expect(restored.date, DateTime(2026, 9, 12, 10, 30));
    });
  });

  group('WalletMovementList 拡張', () {
    final movements = [
      WalletMovement(
        id: 'm1',
        walletId: 'w1',
        amount: 5000,
        date: DateTime(2026, 9, 10),
      ),
      WalletMovement(
        id: 'm3',
        walletId: 'w1',
        amount: -800,
        date: DateTime(2026, 9, 11),
      ),
      WalletMovement(
        id: 'm2',
        walletId: 'w2',
        amount: -200,
        date: DateTime(2026, 9, 12),
      ),
    ];

    test('forWallet は対象のみを日付降順で返す', () {
      final result = movements.forWallet('w1');
      expect(result.map((m) => m.id).toList(), ['m3', 'm1']);
    });

    test('incomeOf / expenseOf は対象財布のみを集計する', () {
      expect(movements.incomeOf('w1'), 5000);
      expect(movements.expenseOf('w1'), 800);
      expect(movements.incomeOf('w2'), 0);
      expect(movements.expenseOf('w2'), 200);
    });

    test('未所有の財布IDのログは除外される', () {
      final filtered = movementsOfWallets(movements, ['w1']);
      expect(filtered.length, 2);
      expect(filtered.every((m) => m.walletId == 'w1'), isTrue);
    });

    test('walletIdsOf はID集合を返す', () {
      const wallets = [Wallet(id: 'w1', name: 'A'), Wallet(id: 'w2', name: 'B')];
      expect(walletIdsOf(wallets), {'w1', 'w2'});
    });
  });

  group('表示整形', () {
    test('formatYen は3桁区切りを付ける', () {
      expect(formatYen(0), '¥0');
      expect(formatYen(1200), '¥1,200');
      expect(formatYen(1200000), '¥1,200,000');
      expect(formatYen(-4500), '-¥4,500');
    });

    test('formatYenSigned は入金に符号を付ける', () {
      expect(formatYenSigned(500), '+¥500');
      expect(formatYenSigned(-500), '-¥500');
    });

    test('formatDate はゼロ埋めする', () {
      expect(formatDate(DateTime(2026, 9, 3)), '2026/09/03');
    });
  });
}
