import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/core/infrastructure/app_lock_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  late AppLockRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repo = AppLockRepository(prefs);
  });

  group('AppLockRepository', () {
    test('初期状態は無効・none・パスコード未設定', () {
      expect(repo.isEnabled(), isFalse);
      expect(repo.getMethod(), AppLockMethod.none);
      expect(repo.getPasscodeHash(), isNull);
    });

    test('setEnabled の保存・復元', () async {
      await repo.setEnabled(true);
      expect(repo.isEnabled(), isTrue);
    });

    test('setMethod の保存・復元', () async {
      await repo.setMethod(AppLockMethod.passcode);
      expect(repo.getMethod(), AppLockMethod.passcode);
      await repo.setMethod(AppLockMethod.biometric);
      expect(repo.getMethod(), AppLockMethod.biometric);
    });

    test('setPasscode → verifyPasscode 正解/不正解', () async {
      await repo.setPasscode('1234');
      expect(repo.verifyPasscode('1234'), isTrue);
      expect(repo.verifyPasscode('0000'), isFalse);
      expect(repo.verifyPasscode(''), isFalse);
    });

    test('ハッシュは平文を含まない', () async {
      await repo.setPasscode('9876');
      final hash = repo.getPasscodeHash()!;
      expect(hash, isNot(contains('9876')));
      expect(hash.length, 64); // SHA-256 hex
    });

    test('clearPasscode 後は検証不可', () async {
      await repo.setPasscode('1111');
      await repo.clearPasscode();
      expect(repo.getPasscodeHash(), isNull);
      expect(repo.verifyPasscode('1111'), isFalse);
    });
  });
}
