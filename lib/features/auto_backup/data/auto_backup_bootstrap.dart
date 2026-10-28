import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:kozuchi/features/auto_backup/data/auto_backup_store.dart';
import 'package:kozuchi/features/auto_backup/domain/auto_backup_policy.dart';
import 'package:kozuchi/features/auto_backup/domain/auto_backup_service.dart';

/// 起動時に自動バックアップを投げっぱなしで予約する。
///
/// 起動経路を妨げないため、戻り値は持たず例外も外へ出さない
/// （失敗は debugPrint のみ）。
void scheduleAutoBackup({
  required Future<String> Function() buildJson,
  required AutoBackupStore store,
  AutoBackupPolicy policy = const AutoBackupPolicy(),
}) {
  unawaited(_run(buildJson: buildJson, store: store, policy: policy));
}

Future<void> _run({
  required Future<String> Function() buildJson,
  required AutoBackupStore store,
  required AutoBackupPolicy policy,
}) async {
  try {
    final result = await AutoBackupService(
      store: store,
      policy: policy,
    ).run(buildJson);
    if (result.ran) {
      debugPrint(
        '[kozuchi] ✅ 自動バックアップ完了: ${result.fileName}'
        '（削除 ${result.pruned.length} 件）',
      );
    } else if (result.error != null) {
      debugPrint('[kozuchi] ⚠️ 自動バックアップ失敗（起動は継続）: ${result.error}');
    }
  } catch (error) {
    debugPrint('[kozuchi] ⚠️ 自動バックアップ失敗（起動は継続）: $error');
  }
}
