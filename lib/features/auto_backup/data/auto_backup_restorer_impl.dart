import 'package:kozuchi/features/auto_backup/data/auto_backup_store.dart';
import 'package:kozuchi/features/auto_backup/domain/auto_backup_policy.dart';
import 'package:kozuchi/features/auto_backup/domain/auto_backup_presenter.dart';
import 'package:kozuchi/features/auto_backup/domain/auto_backup_restorer.dart';

/// 自動バックアップからの復元実装。
///
/// 手順: read → canRestore → **現状を本日分として強制保存** → 既存の
/// インポート経路で適用。例外は全て握りつぶし `ok:false` に変換する
/// （UI を落とさない）。
class AutoBackupRestorerImpl implements AutoBackupRestorer {
  final AutoBackupStore store;
  final AutoBackupPolicy policy;

  /// 現状のバックアップ JSON を採取する（既存エクスポート経路）。
  final Future<String> Function() buildCurrentJson;

  /// 読み出したバックアップ JSON を既存インポート経路で適用する。
  final Future<void> Function(String json) applyBackup;

  /// 現時刻（強制保存のファイル名に用いる）。
  final DateTime Function() now;

  AutoBackupRestorerImpl({
    required this.store,
    required this.buildCurrentJson,
    required this.applyBackup,
    this.policy = const AutoBackupPolicy(),
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  @override
  Future<AutoBackupRestoreResult> restore(String fileName) async {
    try {
      final json = await store.read(fileName);
      if (!AutoBackupPresenter.canRestore(json)) {
        return const AutoBackupRestoreResult(
          ok: false,
          message: 'このバックアップは破損しているため復元できません',
        );
      }

      // 復元前の現状を必ず残す（失敗しても復元は続行する）
      final safetyFileName = AutoBackupPolicy.fileNameFor(now());
      await store.write(safetyFileName, await buildCurrentJson());

      await applyBackup(json!);
      return AutoBackupRestoreResult(
        ok: true,
        message: 'バックアップから復元しました',
        safetyFileName: safetyFileName,
      );
    } catch (error) {
      return AutoBackupRestoreResult(ok: false, message: '$error');
    }
  }
}
