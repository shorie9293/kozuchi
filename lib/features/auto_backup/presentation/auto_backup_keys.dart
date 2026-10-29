import 'package:flutter/widgets.dart';

/// 自動バックアップ一覧画面の試練用 Key を一元管理する。
class AutoBackupAppKeys {
  AutoBackupAppKeys._();

  static const Key screen = Key('auto_backup_screen');
  static const Key list = Key('auto_backup_list');
  static const Key emptyText = Key('auto_backup_empty_text');
  static const Key retentionText = Key('auto_backup_retention_text');
  static const Key backupNowButton = Key('auto_backup_now_button');
  static const Key confirmDialog = Key('auto_backup_confirm_dialog');
  static const Key confirmButton = Key('auto_backup_confirm_button');
  static const Key cancelButton = Key('auto_backup_cancel_button');

  static Key row(String fileName) => Key('auto_backup_row_$fileName');

  static Key restoreButton(String fileName) =>
      Key('auto_backup_restore_$fileName');

  static Key shareButton(String fileName) =>
      Key('auto_backup_share_$fileName');
}
