import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/core/infrastructure/app_lock_repository.dart';
import 'package:kozuchi/core/infrastructure/app_lock_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  late AppLockRepository repo;
  late AppLockService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repo = AppLockRepository(prefs);
    service = AppLockService(repo);
  });

  group('AppLockService', () {
    test('未設定なら常に unlock 成功', () async {
      expect(service.isLocked, isFalse);
      expect(await service.unlock(), isTrue);
    });

    test('enableWithPasscode → isLocked・正解で解除・誤答で失敗', () async {
      await service.enableWithPasscode('4321');
      expect(service.isLocked, isTrue);
      expect(await service.unlock(passcode: '4321'), isTrue);
      expect(await service.unlock(passcode: '1234'), isFalse);
      expect(await service.unlock(), isFalse);
    });

    test('4桁以外・非数字は ArgumentError', () async {
      expect(() => service.enableWithPasscode('123'), throwsArgumentError);
      expect(() => service.enableWithPasscode('12a4'), throwsArgumentError);
    });

    test('biometric 方式は biometricSucceeded で解除', () async {
      await repo.setMethod(AppLockMethod.biometric);
      await repo.setEnabled(true);
      expect(await service.unlock(biometricSucceeded: false), isFalse);
      expect(await service.unlock(biometricSucceeded: true), isTrue);
    });

    test('disable で完全解除', () async {
      await service.enableWithPasscode('2468');
      await service.disable();
      expect(service.isLocked, isFalse);
      expect(repo.getPasscodeHash(), isNull);
      expect(repo.getMethod(), AppLockMethod.none);
    });
  });
}
