import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/core/infrastructure/app_lock_repository.dart';
import 'package:kozuchi/core/infrastructure/app_lock_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 旧形式（salt なし単発 SHA-256）のハッシュ。
String legacyHashOf(String passcode) {
  final bytes = utf8.encode('kozuchi-app-lock:$passcode');
  return sha256.convert(bytes).toString();
}

void main() {
  late SharedPreferences prefs;
  late AppLockRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repo = AppLockRepository(prefs);
  });

  group('v2 ハッシュ形式', () {
    test('v2:<iterations>:<saltHex>:<hashHex> で保存される', () async {
      await repo.setPasscode('1234');
      final stored = repo.getPasscodeHash()!;
      final parts = stored.split(':');
      expect(parts.length, 4);
      expect(parts[0], 'v2');
      expect(parts[1], '1200');
      expect(parts[2].length, 32); // 16バイトの salt を hex 化
      expect(parts[3].length, 64); // SHA-256 hex
      expect(stored, isNot(contains('1234')));
    });

    test('salt はランダムなので同じパスコードでも保存値が異なる', () async {
      await repo.setPasscode('1234');
      final first = repo.getPasscodeHash()!;
      await repo.setPasscode('1234');
      final second = repo.getPasscodeHash()!;
      expect(first, isNot(second));
      expect(first.split(':')[2], isNot(second.split(':')[2]));
      // どちらの保存値でも正しいパスコードは通る。
      expect(repo.verifyPasscode('1234'), isTrue);
    });

    test('保存値と照合結果（正解/不正解）', () async {
      await repo.setPasscode('9876');
      expect(repo.verifyPasscode('9876'), isTrue);
      expect(repo.verifyPasscode('0000'), isFalse);
      expect(repo.verifyPasscode(''), isFalse);
    });

    test('破損した v2 文字列は検証失敗', () async {
      await prefs.setString('app_lock.passcode_hash', 'v2:1200:abcd');
      expect(repo.verifyPasscode('1234'), isFalse);
      await prefs.setString('app_lock.passcode_hash', 'v2:x:abcd:ef');
      expect(repo.verifyPasscode('1234'), isFalse);
    });
  });

  group('旧形式からの移行', () {
    test('旧形式でも照合でき、成功時に v2 へ移行する', () async {
      await prefs.setString('app_lock.passcode_hash', legacyHashOf('1357'));
      expect(repo.getPasscodeHash()!.startsWith('v2:'), isFalse);

      expect(repo.verifyPasscode('1357'), isTrue);
      expect(repo.verifyPasscode('0000'), isFalse);

      // 投げっぱなしの再保存を待つ。
      await pumpEventQueue();
      final migrated = repo.getPasscodeHash()!;
      expect(migrated.startsWith('v2:'), isTrue);
      expect(repo.verifyPasscode('1357'), isTrue);
      expect(repo.verifyPasscode('0000'), isFalse);
    });

    test('旧形式で不一致なら移行しない', () async {
      await prefs.setString('app_lock.passcode_hash', legacyHashOf('1357'));
      expect(repo.verifyPasscode('2468'), isFalse);
      await pumpEventQueue();
      expect(repo.getPasscodeHash(), legacyHashOf('1357'));
    });
  });

  group('猶予・試行回数の往復', () {
    test('猶予秒数の既定は 0・保存/復元', () async {
      expect(repo.getRelockGraceSeconds(), 0);
      await repo.setRelockGraceSeconds(60);
      expect(repo.getRelockGraceSeconds(), 60);
      expect(() => repo.setRelockGraceSeconds(-1), throwsArgumentError);
    });

    test('失敗件数と lockedUntil の往復・resetAttempts', () async {
      expect(repo.getFailedAttempts(), 0);
      expect(repo.getLockedUntil(), isNull);

      final until = DateTime(2026, 1, 1, 12, 0, 30);
      await repo.setFailedAttempts(5);
      await repo.setLockedUntil(until);
      expect(repo.getFailedAttempts(), 5);
      expect(repo.getLockedUntil(), until);

      await repo.resetAttempts();
      expect(repo.getFailedAttempts(), 0);
      expect(repo.getLockedUntil(), isNull);
    });
  });

  group('試行制限の連携', () {
    test('5回失敗でロックアウトし、時間経過で解除・成功で回数リセット', () async {
      var clock = DateTime(2026, 1, 1, 12, 0, 0);
      final service = AppLockService(repo, now: () => clock);
      await service.enableWithPasscode('1357');

      for (var i = 0; i < 5; i++) {
        expect(await service.unlock(passcode: '0000'), isFalse);
      }
      expect(repo.getFailedAttempts(), 5);
      expect(repo.getLockedUntil(), clock.add(const Duration(seconds: 30)));
      expect(service.isLockedOut, isTrue);
      expect(service.lockoutRemainingSeconds, 30);

      // ロックアウト中は正解でも通らない。
      expect(await service.unlock(passcode: '1357'), isFalse);

      clock = clock.add(const Duration(seconds: 31));
      expect(service.isLockedOut, isFalse);
      expect(service.lockoutRemainingSeconds, 0);
      expect(await service.unlock(passcode: '1357'), isTrue);
      expect(repo.getFailedAttempts(), 0);
      expect(repo.getLockedUntil(), isNull);
    });

    test('猶予設定はサービス経由で保存される', () async {
      final service = AppLockService(repo);
      expect(service.relockGrace, Duration.zero);
      await service.setRelockGrace(const Duration(minutes: 5));
      expect(service.relockGrace, const Duration(minutes: 5));
      expect(repo.getRelockGraceSeconds(), 300);
      expect(
        () => service.setRelockGrace(const Duration(seconds: -1)),
        throwsArgumentError,
      );
    });
  });
}
