import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/core/infrastructure/lock_attempt_policy.dart';

void main() {
  final now = DateTime(2026, 1, 1, 12, 0, 0);

  group('定数', () {
    test('無償試行5回・30秒・上限15分', () {
      expect(LockAttemptPolicy.maxFreeAttempts, 5);
      expect(LockAttemptPolicy.baseLockout, const Duration(seconds: 30));
      expect(LockAttemptPolicy.maxLockout, const Duration(minutes: 15));
    });
  });

  group('lockoutFor', () {
    test('5回未満はロックアウトしない', () {
      for (var n = 0; n < 5; n++) {
        expect(LockAttemptPolicy.lockoutFor(n), Duration.zero, reason: 'n=$n');
      }
    });

    test('5回で30秒・以降5回ごとに倍', () {
      expect(LockAttemptPolicy.lockoutFor(5), const Duration(seconds: 30));
      expect(LockAttemptPolicy.lockoutFor(9), const Duration(seconds: 30));
      expect(LockAttemptPolicy.lockoutFor(10), const Duration(seconds: 60));
      expect(LockAttemptPolicy.lockoutFor(15), const Duration(seconds: 120));
      expect(LockAttemptPolicy.lockoutFor(20), const Duration(seconds: 240));
      expect(LockAttemptPolicy.lockoutFor(25), const Duration(seconds: 480));
    });

    test('上限は15分', () {
      expect(LockAttemptPolicy.lockoutFor(30), const Duration(minutes: 15));
      expect(LockAttemptPolicy.lockoutFor(500), const Duration(minutes: 15));
      expect(
        LockAttemptPolicy.lockoutFor(999999),
        const Duration(minutes: 15),
      );
    });
  });

  group('isLockedOut', () {
    test('null はロックアウト外', () {
      expect(LockAttemptPolicy.isLockedOut(null, now), isFalse);
    });

    test('未来ならロックアウト中・過去なら解除済み', () {
      expect(
        LockAttemptPolicy.isLockedOut(
          now.add(const Duration(seconds: 1)),
          now,
        ),
        isTrue,
      );
      expect(
        LockAttemptPolicy.isLockedOut(
          now.subtract(const Duration(seconds: 1)),
          now,
        ),
        isFalse,
      );
      expect(LockAttemptPolicy.isLockedOut(now, now), isFalse);
    });
  });

  group('remainingSeconds', () {
    test('未設定・過去は 0', () {
      expect(LockAttemptPolicy.remainingSeconds(null, now), 0);
      expect(
        LockAttemptPolicy.remainingSeconds(
          now.subtract(const Duration(seconds: 5)),
          now,
        ),
        0,
      );
    });

    test('端数は切り上げ', () {
      expect(
        LockAttemptPolicy.remainingSeconds(
          now.add(const Duration(milliseconds: 1500)),
          now,
        ),
        2,
      );
      expect(
        LockAttemptPolicy.remainingSeconds(
          now.add(const Duration(seconds: 30)),
          now,
        ),
        30,
      );
    });
  });

  group('lockoutLabel', () {
    test('残り秒数を含む案内文', () {
      expect(
        LockAttemptPolicy.lockoutLabel(30),
        'しばらく待ってから再試行してください（残り30秒）',
      );
      expect(
        LockAttemptPolicy.lockoutLabel(0),
        'しばらく待ってから再試行してください（残り0秒）',
      );
    });
  });
}
