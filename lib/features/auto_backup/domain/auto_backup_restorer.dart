/// 自動バックアップからの復元結果。
class AutoBackupRestoreResult {
  /// 復元が成功したか。
  final bool ok;

  /// 利用者に示す文言（失敗理由を含む）。
  final String? message;

  /// 復元前に強制保存した現状バックアップのファイル名。
  final String? safetyFileName;

  const AutoBackupRestoreResult({
    required this.ok,
    this.message,
    this.safetyFileName,
  });

  @override
  String toString() =>
      'AutoBackupRestoreResult(ok: $ok, message: $message, '
      'safetyFileName: $safetyFileName)';
}

/// 自動バックアップ1世代を現世データへ適用する抽象。
///
/// 実装は `AutoBackupRestorerImpl`（read → 現状強制保存 → 適用）。
abstract interface class AutoBackupRestorer {
  /// [fileName] の世代を復元する。例外は実装側で握る。
  Future<AutoBackupRestoreResult> restore(String fileName);
}
