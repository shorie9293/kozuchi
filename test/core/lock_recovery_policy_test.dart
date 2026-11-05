import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/core/infrastructure/lock_recovery_policy.dart';

void main() {
  group('LockRecoveryPolicy', () {
    test('ロック有効時のみ回復を許可する', () {
      expect(LockRecoveryPolicy.canRecover(enabled: true), isTrue);
      expect(LockRecoveryPolicy.canRecover(enabled: false), isFalse);
    });

    test('確認語は「初期化」で固定される', () {
      expect(LockRecoveryPolicy.confirmationPhrase, '初期化');
    });

    test('確認語の完全一致のみ有効', () {
      expect(LockRecoveryPolicy.isConfirmationValid('初期化'), isTrue);
      expect(LockRecoveryPolicy.isConfirmationValid('初期化 '), isTrue);
      expect(LockRecoveryPolicy.isConfirmationValid(' 初期化'), isTrue);
      expect(LockRecoveryPolicy.isConfirmationValid('初期'), isFalse);
      expect(LockRecoveryPolicy.isConfirmationValid('初期化し'), isFalse);
      expect(LockRecoveryPolicy.isConfirmationValid(''), isFalse);
      expect(LockRecoveryPolicy.isConfirmationValid('初期化初期化'), isFalse);
    });

    test('警告文はデータ消失の不可逆性を明示する', () {
      expect(LockRecoveryPolicy.warningText, contains('復元できません'));
      expect(LockRecoveryPolicy.warningText, contains('バックアップ'));
    });
  });
}
