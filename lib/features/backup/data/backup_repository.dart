import 'package:shared_preferences/shared_preferences.dart';

import 'package:kozuchi/features/backup/domain/backup_models.dart';
import 'package:kozuchi/features/backup/domain/backup_service.dart';

/// エクスポート／リストアの永続化インターフェース。
///
/// collect で現状を採取し、restore でバンドルを既存データへ書き戻す。
abstract interface class BackupRepository {
  /// 現在の SharedPreferences スナップショットを採取する。
  Future<BackupBundle> collect();

  /// バンドルを既存データへ復元して結果を返す。
  Future<RestoreResult> restore(BackupBundle bundle);
}

/// SharedPreferences を用いた [BackupRepository] 実装。
class SharedPreferencesBackupRepository implements BackupRepository {
  final DateTime Function() now;
  final BackupService _service;

  SharedPreferencesBackupRepository({DateTime Function()? now})
      : now = now ?? DateTime.now,
        _service = BackupService(now: now ?? DateTime.now);

  @override
  Future<BackupBundle> collect() async {
    final prefs = await SharedPreferences.getInstance();
    final snapshot = <String, Object?>{
      for (final key in prefs.getKeys()) key: prefs.get(key),
    };
    return _service.build(snapshot);
  }

  @override
  Future<RestoreResult> restore(BackupBundle bundle) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = <String, Object?>{
      for (final key in prefs.getKeys()) key: prefs.get(key),
    };
    final diff = _service.diff(
      bundle: bundle,
      existing: existing,
    );

    // 新規・更新対象のみを型に応じて書き戻す
    final targets = <String, Object?>{...diff.toCreate, ...diff.toOverwrite};
    for (final entry in targets.entries) {
      final key = entry.key;
      final value = entry.value;
      if (value is String) {
        await prefs.setString(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      } else if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is List) {
        await prefs.setStringList(
          key,
          List<String>.of(value.cast<String>()),
        );
      }
    }
    return diff.result;
  }
}

/// テスト・プレビュー用のインメモリ [BackupRepository] 実装。
class InMemoryBackupRepository implements BackupRepository {
  final Map<String, Object?> store;
  final BackupService _service;

  InMemoryBackupRepository([Map<String, Object?>? store])
      : store = store ?? {},
        _service = BackupService(now: DateTime.now);

  @override
  Future<BackupBundle> collect() async {
    return _service.build(store);
  }

  @override
  Future<RestoreResult> restore(BackupBundle bundle) async {
    final diff = _service.diff(bundle: bundle, existing: store);
    for (final key in diff.toCreate.keys) {
      store[key] = bundle.entries[key];
    }
    for (final key in diff.toOverwrite.keys) {
      store[key] = bundle.entries[key];
    }
    return diff.result;
  }
}

/// 何もしない [BackupRepository] 実装（プレビュー等の無効化用）。
class NoopBackupRepository implements BackupRepository {
  const NoopBackupRepository();

  @override
  Future<BackupBundle> collect() async {
    return BackupBundle(
      exportedAt: DateTime.now().toUtc(),
      entries: {},
    );
  }

  @override
  Future<RestoreResult> restore(BackupBundle bundle) async {
    return const RestoreResult(
      created: 0,
      restored: 0,
      unchanged: 0,
    );
  }
}