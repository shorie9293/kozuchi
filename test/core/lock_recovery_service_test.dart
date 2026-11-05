import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/core/infrastructure/app_lock_repository.dart';
import 'package:kozuchi/core/infrastructure/app_lock_service.dart';
import 'package:kozuchi/core/infrastructure/lock_recovery_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 書き出しの呼び出しを記録するフェイク。
class _FakeExporter implements LockRecoveryBackupExporter {
  _FakeExporter({this.throwOnExport = false, this.isLockedDuringExport});

  final bool throwOnExport;
  final bool Function()? isLockedDuringExport;
  int calls = 0;
  bool? lockedAtExport;

  @override
  Future<void> export() async {
    calls++;
    lockedAtExport = isLockedDuringExport?.call();
    if (throwOnExport) {
      throw StateError('backup failed');
    }
  }
}

/// 消去の呼び出しを記録するフェイク。
class _FakeEraser implements LockRecoveryDataEraser {
  _FakeEraser({this.throwOnErase = false});

  final bool throwOnErase;
  int calls = 0;

  @override
  Future<void> erase() async {
    calls++;
    if (throwOnErase) {
      throw StateError('erase failed');
    }
  }
}

void main() {
  late SharedPreferences prefs;
  late AppLockRepository repo;
  late AppLockService appLock;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repo = AppLockRepository(prefs);
    appLock = AppLockService(repo);
  });

  Future<void> lockApp() => appLock.enableWithPasscode('1357');

  test('ロック無効なら rejected で何も変更しない', () async {
    final exporter = _FakeExporter();
    final eraser = _FakeEraser();
    final service = LockRecoveryService(
      appLock,
      backupExporter: exporter,
      dataEraser: eraser,
    );

    final result = await service.recover(confirmation: '初期化');

    expect(result.isRejected, isTrue);
    expect(result.lockReleased, isFalse);
    expect(exporter.calls, 0);
    expect(eraser.calls, 0);
    expect(appLock.isLocked, isFalse);
  });

  test('確認語不一致なら rejected でロックもデータも不変', () async {
    await lockApp();
    final exporter = _FakeExporter();
    final eraser = _FakeEraser();
    final service = LockRecoveryService(
      appLock,
      backupExporter: exporter,
      dataEraser: eraser,
    );

    final result = await service.recover(confirmation: '解除');

    expect(result.isRejected, isTrue);
    expect(exporter.calls, 0);
    expect(eraser.calls, 0);
    expect(appLock.isLocked, isTrue);
    expect(repo.verifyPasscode('1357'), isTrue);
  });

  test('成功時はロック解除・パスコード消去・データ消去まで行う', () async {
    await lockApp();
    final exporter = _FakeExporter();
    final eraser = _FakeEraser();
    final service = LockRecoveryService(
      appLock,
      backupExporter: exporter,
      dataEraser: eraser,
    );

    final result = await service.recover(confirmation: '初期化');

    expect(result.isRecovered, isTrue);
    expect(result.backupFailed, isFalse);
    expect(result.dataWiped, isTrue);
    expect(appLock.isLocked, isFalse);
    expect(repo.getPasscodeHash(), isNull);
    expect(repo.verifyPasscode('1357'), isFalse);
    expect(exporter.calls, 1);
    expect(eraser.calls, 1);
  });

  test('バックアップはロック解除より前に実行される', () async {
    await lockApp();
    final exporter = _FakeExporter(isLockedDuringExport: () => appLock.isLocked);
    final service = LockRecoveryService(appLock, backupExporter: exporter);

    await service.recover(confirmation: '初期化');

    expect(exporter.calls, 1);
    expect(exporter.lockedAtExport, isTrue,
        reason: '書き出し時点ではまだロック中であるべき');
    expect(appLock.isLocked, isFalse);
  });

  test('バックアップ失敗でも回復は成立する（backupFailed 記録）', () async {
    await lockApp();
    final exporter = _FakeExporter(throwOnExport: true);
    final eraser = _FakeEraser();
    final service = LockRecoveryService(
      appLock,
      backupExporter: exporter,
      dataEraser: eraser,
    );

    final result = await service.recover(confirmation: '初期化');

    expect(result.isRecovered, isTrue);
    expect(result.backupFailed, isTrue);
    expect(result.dataWiped, isTrue);
    expect(appLock.isLocked, isFalse);
  });

  test('データ消去失敗でもロック解除は成立する（fail-safe）', () async {
    await lockApp();
    final exporter = _FakeExporter();
    final eraser = _FakeEraser(throwOnErase: true);
    final service = LockRecoveryService(
      appLock,
      backupExporter: exporter,
      dataEraser: eraser,
    );

    final result = await service.recover(confirmation: '初期化');

    expect(result.isRecovered, isTrue);
    expect(result.dataWiped, isFalse);
    expect(appLock.isLocked, isFalse);
    expect(repo.getPasscodeHash(), isNull);
  });
}
