/// 自動バックアップの1世代分を表す。
///
/// ファイル名と作成時刻のみを持ち、IO には関与しない。
class AutoBackupEntry {
  final String fileName;
  final DateTime createdAt;

  const AutoBackupEntry({required this.fileName, required this.createdAt});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AutoBackupEntry &&
          other.fileName == fileName &&
          other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(fileName, createdAt);

  @override
  String toString() => 'AutoBackupEntry($fileName, $createdAt)';
}

/// 自動バックアップの方針（実行間隔・世代数・命名規則・世代整理）。
///
/// 純粋な判定のみを担い、ファイルシステムには触れない。
class AutoBackupPolicy {
  /// 保持する世代数（既定3世代）。
  static const int defaultKeep = 3;

  /// 実行間隔（既定24時間＝起動時1日1回）。
  static const Duration defaultInterval = Duration(hours: 24);

  /// 自動バックアップファイル名の接頭辞。
  static const String filePrefix = 'auto_backup_';

  /// 自動バックアップファイル名の拡張子。
  static const String fileSuffix = '.json';

  final Duration interval;
  final int keep;

  const AutoBackupPolicy({
    this.interval = defaultInterval,
    this.keep = defaultKeep,
  });

  /// 実行すべきか。
  ///
  /// - 前回が無ければ実行する
  /// - ちょうど [interval] 経過も実行対象に含める
  /// - 前回が未来時刻（端末時計の巻き戻り等）でも実行する
  bool shouldRun({DateTime? lastAt, required DateTime now}) {
    if (lastAt == null) return true;
    final elapsed = now.difference(lastAt);
    if (elapsed.isNegative) return true;
    return elapsed >= interval;
  }

  /// ローカル暦の日付から自動バックアップのファイル名を組み立てる。
  ///
  /// 例: 2026-01-05 → `auto_backup_20260105.json`
  /// （UTC 変換は行わない。ユーザーの暦日で1日1回を数えるため）
  static String fileNameFor(DateTime now) {
    final yyyy = now.year.toString().padLeft(4, '0');
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    return '$filePrefix$yyyy$mm$dd$fileSuffix';
  }

  /// 自動バックアップの命名規則に一致するか。
  static bool isAutoBackupFile(String name) {
    if (name.length <= filePrefix.length + fileSuffix.length) return false;
    return name.startsWith(filePrefix) && name.endsWith(fileSuffix);
  }

  /// 与えられた世代のうち最新の作成時刻（空なら null）。
  DateTime? latestCreatedAt(List<AutoBackupEntry> entries) {
    if (entries.isEmpty) return null;
    var latest = entries.first.createdAt;
    for (final entry in entries.skip(1)) {
      if (entry.createdAt.isAfter(latest)) latest = entry.createdAt;
    }
    return latest;
  }

  /// 保持数を超えた世代（削除対象）を返す。
  ///
  /// - 自動バックアップ命名のファイルのみを対象とする（手動ファイルは返さない）
  /// - createdAt 降順（同時刻は fileName 降順）で新しい [keep] 件を残す
  /// - 返却順は削除対象の古い順
  List<AutoBackupEntry> prune(List<AutoBackupEntry> entries) {
    final limit = keep < 0 ? 0 : keep;
    final auto = entries
        .where((entry) => isAutoBackupFile(entry.fileName))
        .toList()
      ..sort((a, b) {
        final byCreatedAt = b.createdAt.compareTo(a.createdAt);
        if (byCreatedAt != 0) return byCreatedAt;
        return b.fileName.compareTo(a.fileName);
      });
    if (auto.length <= limit) return const <AutoBackupEntry>[];
    // 降順ソートの後半（＝残す世代より古い分）を、古い順に反転して返す
    return auto.sublist(limit).reversed.toList(growable: false);
  }
}
