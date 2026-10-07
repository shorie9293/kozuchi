import 'dart:convert';

import 'package:kozuchi/features/backup/domain/backup_models.dart';

/// エクスポート／バックアップのドメインサービス。
///
/// スナップショット抽出・JSON 整形・パース・復元差分計算を担う。
/// UI・永続化には関与しない（純粋な計算に徹する・IO禁止）。
class BackupService {
  final DateTime Function() _now;

  /// [now] を注入できる（既定は [DateTime.now]）。
  const BackupService({DateTime Function()? now})
      : _now = now ?? DateTime.now;

  /// バックアップ対象キーかどうか（プレフィックス or 完全一致）。
  static bool isBackupKey(String key) =>
      kBackupKeyPrefixes.any(key.startsWith) || kBackupKeyExact.contains(key);

  /// 生スナップショット（キー→値）から [BackupBundle] を組み立てる。
  ///
  /// - [isBackupKey] を満たすキーのみ抽出する
  /// - 値は String/int/double/bool/List<String>（要素全てString）のみ採用し、
  ///   それ以外の型の値はスキップする（例外は投げない）
  /// - exportedAt は UTC
  /// - entries のキーは昇順ソートして順序を安定させる
  BackupBundle build(Map<String, Object?> rawSnapshot) {
    final picked = <String, Object?>{};
    final keys = rawSnapshot.keys.where(isBackupKey).toList()..sort();
    for (final key in keys) {
      final value = rawSnapshot[key];
      if (value is String ||
          value is int ||
          value is double ||
          value is bool) {
        picked[key] = value;
        continue;
      }
      if (value is List && value.every((item) => item is String)) {
        picked[key] = List<String>.of(value.cast<String>());
      }
      // それ以外の型の値はスキップ（例外を投げない）
    }
    return BackupBundle(
      exportedAt: _now().toUtc(),
      entries: Map.of(picked),
    );
  }

  /// 整形JSON（2スペースインデント）へ書き出す。
  String exportJson(BackupBundle bundle) {
    return const JsonEncoder.withIndent('  ').convert(bundle.toJson());
  }

  /// 整形JSONをパースして [BackupBundle] に復元する。
  ///
  /// 破損JSON・非オブジェクト・必須欠落は [FormatException]。
  BackupBundle parse(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      rethrow;
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Backup JSON must be an object');
    }
    return BackupBundle.fromJson(decoded);
  }

  /// 復元差分を計算する。
  ///
  /// bundle.entries の各キーについて、
  /// - existing に無いキー → toCreate
  /// - 値が異なるキー → toOverwrite
  /// - 同値 → unchanged に計上
  RestoreDiff diff({
    required BackupBundle bundle,
    required Map<String, Object?> existing,
  }) {
    final toCreate = <String, Object?>{};
    final toOverwrite = <String, Object?>{};
    var unchanged = 0;
    bundle.entries.forEach((key, value) {
      if (!existing.containsKey(key)) {
        toCreate[key] = value;
      } else if (!_valueEquals(existing[key], value)) {
        toOverwrite[key] = value;
      } else {
        unchanged++;
      }
    });
    return RestoreDiff(
      toCreate: toCreate,
      toOverwrite: toOverwrite,
      unchanged: unchanged,
    );
  }

  /// エクスポートファイル名の候補（例: kozuchi_backup_20261007_1900.json）。
  static String suggestedFileName(DateTime now) {
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final hh = now.hour.toString().padLeft(2, '0');
    final mi = now.minute.toString().padLeft(2, '0');
    return 'kozuchi_backup_${now.year}$mm${dd}_$hh$mi.json';
  }

  /// スナップショット値の同値判定。
  ///
  /// Dart の `!=` はリストに対して同一性比較のため、
  /// List<String> は要素比較（listEquals 相当）で判定する。
  static bool _valueEquals(Object? a, Object? b) {
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_valueEquals(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }
}

/// 復元差分（新規作成対象・上書き対象・変更なし件数）。
class RestoreDiff {
  final Map<String, Object?> toCreate;
  final Map<String, Object?> toOverwrite;
  final int unchanged;

  const RestoreDiff({
    required this.toCreate,
    required this.toOverwrite,
    required this.unchanged,
  });

  int get created => toCreate.length;

  int get restored => toOverwrite.length;

  RestoreResult get result => RestoreResult(
        created: created,
        restored: restored,
        unchanged: unchanged,
      );
}