import 'package:shared_preferences/shared_preferences.dart';

import '../../features/backup/data/backup_file_io.dart';
import '../../features/backup/data/backup_repository.dart';
import '../../features/backup/domain/backup_service.dart';
import 'app_lock_service.dart';
import 'lock_recovery_policy.dart';

/// 回復前のバックアップ書き出し（失敗しても回復は続行する）。
abstract interface class LockRecoveryBackupExporter {
  /// 現在のデータを書き出す。
  Future<void> export();
}

/// 回復時のデータ初期化（失敗してもロック解除は取り消さない）。
abstract interface class LockRecoveryDataEraser {
  /// ローカルの記録データを初期化する。
  Future<void> erase();
}

/// 回復処理の帰結。
enum LockRecoveryStatus {
  /// 前提を満たさず何も変更していない（ロック無効・確認語不一致）。
  rejected,

  /// ロックを解除し、データ初期化まで到達した（初期化失敗を含む）。
  recovered,

  /// ロック解除自体に失敗した（データには触れていない）。
  disableFailed,
}

/// 回復処理の結果。
class LockRecoveryResult {
  const LockRecoveryResult({
    required this.status,
    this.backupFailed = false,
    this.dataWiped = false,
  });

  final LockRecoveryStatus status;

  /// バックアップ書き出しに失敗したか。
  final bool backupFailed;

  /// データ初期化まで成功したか。
  final bool dataWiped;

  /// 何も変更せず拒否したか。
  bool get isRejected => status == LockRecoveryStatus.rejected;

  /// ロック解除まで到達したか（データ初期化の成否を問わない）。
  bool get lockReleased => status == LockRecoveryStatus.recovered;

  /// 回復が完了したか。
  bool get isRecovered => status == LockRecoveryStatus.recovered;
}

/// パスコード忘却時の回復手順。
///
/// 手順は固定：二段確認 → バックアップ書き出し（best-effort）→ ロック解除 →
/// データ初期化（best-effort）。初期化やバックアップが失敗してもロックは
/// 必ず解除する（fail-safe）。例外は呼び出し元へ投げない。
class LockRecoveryService {
  final AppLockService _appLock;
  final LockRecoveryBackupExporter? _backupExporter;
  final LockRecoveryDataEraser? _dataEraser;

  LockRecoveryService(
    this._appLock, {
    LockRecoveryBackupExporter? backupExporter,
    LockRecoveryDataEraser? dataEraser,
  })  : _backupExporter = backupExporter,
        _dataEraser = dataEraser;

  /// 回復を実行する。[confirmation] は確認語（[LockRecoveryPolicy] 参照）。
  Future<LockRecoveryResult> recover({required String confirmation}) async {
    if (!LockRecoveryPolicy.canRecover(enabled: _appLock.isLocked)) {
      return const LockRecoveryResult(status: LockRecoveryStatus.rejected);
    }
    if (!LockRecoveryPolicy.isConfirmationValid(confirmation)) {
      return const LockRecoveryResult(status: LockRecoveryStatus.rejected);
    }

    var backupFailed = false;
    final exporter = _backupExporter;
    if (exporter != null) {
      try {
        await exporter.export();
      } catch (_) {
        backupFailed = true;
      }
    }

    try {
      await _appLock.disable();
    } catch (_) {
      return LockRecoveryResult(
        status: LockRecoveryStatus.disableFailed,
        backupFailed: backupFailed,
      );
    }

    var dataWiped = false;
    final eraser = _dataEraser;
    if (eraser != null) {
      try {
        await eraser.erase();
        dataWiped = true;
      } catch (_) {
        dataWiped = false;
      }
    }

    return LockRecoveryResult(
      status: LockRecoveryStatus.recovered,
      backupFailed: backupFailed,
      dataWiped: dataWiped,
    );
  }
}

/// 既存のバックアップ機構（[BackupService] + [BackupExporter]）を再利用する実装。
class SharedPreferencesLockBackupExporter
    implements LockRecoveryBackupExporter {
  final BackupExporter _exporter;
  final DateTime Function() _now;

  SharedPreferencesLockBackupExporter({
    BackupExporter? exporter,
    DateTime Function()? now,
  })  : _exporter = exporter ?? const SharePlusBackupExporter(),
        _now = now ?? DateTime.now;

  @override
  Future<void> export() async {
    final repository = SharedPreferencesBackupRepository(now: _now);
    final bundle = await repository.collect();
    final service = BackupService(now: _now);
    await _exporter.export(
      json: service.exportJson(bundle),
      fileName: BackupService.suggestedFileName(_now()),
    );
  }
}

/// SharedPreferences 上の記録データをすべて消す実装。
///
/// この現世のローカルデータは SharedPreferences に載っているため、
/// 全キーの削除がデータ初期化に相当する。
class SharedPreferencesLockDataEraser implements LockRecoveryDataEraser {
  const SharedPreferencesLockDataEraser();

  @override
  Future<void> erase() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
