import 'dart:convert';

import 'package:kozuchi/features/auto_backup/domain/auto_backup_policy.dart';

/// 一覧1行分の表示用データ。
///
/// [byteSize]・[generation]・[restorable] は読み出した内容から算出済み。
class AutoBackupRow {
  final AutoBackupEntry entry;

  /// 内容の UTF8 バイト長（読み出せなければ 0）。
  final int byteSize;

  /// 新しい順の世代番号（最新が1）。
  final int generation;

  /// 復元可能か（JSON オブジェクトとして解釈できるか）。
  final bool restorable;

  const AutoBackupRow({
    required this.entry,
    required this.byteSize,
    required this.generation,
    required this.restorable,
  });

  /// 例: `2026-10-29 07:12`
  String get dateLabel => AutoBackupPresenter.formatDate(entry.createdAt);

  /// 例: `12.4 KB`
  String get sizeLabel => AutoBackupPresenter.formatSize(byteSize);

  /// 例: `2026-10-29 07:12 / 12.4 KB / 第1世代`
  String get displayLabel => '$dateLabel / $sizeLabel / 第$generation世代';
}

/// 自動バックアップ一覧の表示整形（純粋計算・I/O なし）。
class AutoBackupPresenter {
  /// 保持世代数（[retentionLabel] の表示に用いる）。
  final int keep;

  const AutoBackupPresenter({this.keep = AutoBackupPolicy.defaultKeep});

  /// ローカル暦で `yyyy-MM-dd HH:mm` に整形する。
  static String formatDate(DateTime at) {
    final local = at.toLocal();
    final yyyy = local.year.toString().padLeft(4, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mi = local.minute.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd $hh:$mi';
  }

  /// バイト長を 1024 基数で整形する（1024未満は B）。
  ///
  /// 例: `512 B` / `12.4 KB` / `1.2 MB`
  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }

  /// 復元できる内容か。例外は決して投げない。
  ///
  /// null・空・JSONパース失敗・トップが Map でない → false。
  static bool canRestore(String? json) {
    if (json == null) return false;
    final trimmed = json.trim();
    if (trimmed.isEmpty) return false;
    try {
      return jsonDecode(trimmed) is Map;
    } catch (_) {
      return false;
    }
  }

  /// createdAt 降順（同時刻は fileName 降順）に並べ替えた新しいリストを返す。
  static List<AutoBackupEntry> sortNewestFirst(List<AutoBackupEntry> entries) {
    final sorted = List<AutoBackupEntry>.of(entries);
    sorted.sort((a, b) {
      final byCreatedAt = b.createdAt.compareTo(a.createdAt);
      if (byCreatedAt != 0) return byCreatedAt;
      return b.fileName.compareTo(a.fileName);
    });
    return sorted;
  }

  /// 例: `保持 3世代中 2件`
  String retentionLabel(int count) => '保持 $keep世代中 $count件';

  /// 一覧行を組み立てる。
  ///
  /// - 自動バックアップ命名のファイルのみ対象
  /// - 新しい順・generation は1始まり
  /// - byteSize は UTF8 長・restorable は [canRestore]
  List<AutoBackupRow> buildRows({
    required List<AutoBackupEntry> entries,
    required Map<String, String?> contents,
  }) {
    final targets = entries
        .where((entry) => AutoBackupPolicy.isAutoBackupFile(entry.fileName))
        .toList();
    final sorted = sortNewestFirst(targets);
    final rows = <AutoBackupRow>[];
    for (var i = 0; i < sorted.length; i++) {
      final entry = sorted[i];
      final content = contents[entry.fileName];
      rows.add(
        AutoBackupRow(
          entry: entry,
          byteSize: content == null ? 0 : utf8.encode(content).length,
          generation: i + 1,
          restorable: canRestore(content),
        ),
      );
    }
    return rows;
  }
}
