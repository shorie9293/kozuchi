import 'package:flutter/widgets.dart';

/// バックアップと復元画面の試練用Key一元管理
class BackupAppKeys {
  const BackupAppKeys._();

  static const Key screen = Key('backupScreen');
  static const Key appBarTitle = Key('backupAppBarTitle');
  static const Key exportButton = Key('backupExportButton');
  static const Key restoreButton = Key('backupRestoreButton');
  static const Key entryCountText = Key('backupEntryCountText');
  static const Key emptyText = Key('backupEmptyText');
  static const Key snapshotList = Key('backupSnapshotList');
  static const Key confirmRestoreDialog = Key('backupConfirmRestoreDialog');
  static const Key confirmRestoreButton = Key('backupConfirmRestoreButton');
  static const Key cancelRestoreButton = Key('backupCancelRestoreButton');

  static Key row(String key) => Key('backup_row_$key');
}
