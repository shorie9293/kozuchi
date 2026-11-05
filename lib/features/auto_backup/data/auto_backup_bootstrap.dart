import 'dart:async';

import 'package:kozuchi/core/logging/app_logger.dart';
import 'package:kozuchi/features/auto_backup/data/auto_backup_status_store.dart';
import 'package:kozuchi/features/auto_backup/data/auto_backup_store.dart';
import 'package:kozuchi/features/auto_backup/domain/auto_backup_policy.dart';
import 'package:kozuchi/features/auto_backup/domain/auto_backup_service.dart';

/// 起動時に自動バックアップを投げっぱなしで予約する。
///
/// 起動経路を妨げないため、戻り値は持たず例外も外へ出さない
/// （失敗は appLog.warn のみ）。
/// 成否は [statusStore] に記録し、画面が「未実行」と「毎回失敗」を
/// 区別できるようにする。
void scheduleAutoBackup({
  required Future<String> Function() buildJson,
  required AutoBackupStore store,
  AutoBackupPolicy policy = const AutoBackupPolicy(),
  AutoBackupStatusStore? statusStore,
}) {
  unawaited(
    _run(
      buildJson: buildJson,
      store: store,
      policy: policy,
      statusStore: statusStore ?? FileAutoBackupStatusStore(),
    ),
  );
}

Future<void> _run({
  required Future<String> Function() buildJson,
  required AutoBackupStore store,
  required AutoBackupPolicy policy,
  required AutoBackupStatusStore statusStore,
}) async {
  try {
    final result = await AutoBackupService(
      store: store,
      policy: policy,
      statusStore: statusStore,
    ).run(buildJson);
    if (result.ran) {
      appLog.debug(
        '[kozuchi] ✅ 自動バックアップ完了: ${result.fileName}'
        '（削除 ${result.pruned.length} 件）',
      );
    } else if (result.error != null) {
      appLog.warn('[kozuchi] 自動バックアップ失敗（起動は継続）', result.error);
    }
  } catch (error) {
    appLog.warn('[kozuchi] 自動バックアップ失敗（起動は継続）', error);
  }
}
