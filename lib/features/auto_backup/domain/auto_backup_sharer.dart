/// 自動バックアップ1世代を外部へ共有する抽象。
///
/// 実装は `SharePlusAutoBackupSharer`（一時ファイル＋share_plus）。
abstract interface class AutoBackupSharer {
  /// [fileName] という名前で [json] を共有する。
  Future<void> share(String fileName, String json);
}
