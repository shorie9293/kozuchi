import 'package:kozuchi/features/auto_backup/data/auto_backup_status_store.dart';
import 'package:kozuchi/features/auto_backup/data/auto_backup_store.dart';
import 'package:kozuchi/features/auto_backup/domain/auto_backup_policy.dart';
import 'package:kozuchi/features/auto_backup/domain/auto_backup_status.dart';

/// 自動バックアップ実行の結果。
class AutoBackupResult {
  /// 実際に書き出したか（間隔未経過のスキップ・例外時は false）。
  final bool ran;

  /// 書き出したファイル名（スキップ・例外時は null）。
  final String? fileName;

  /// 世代整理で削除したファイル名（古い順）。
  final List<String> pruned;

  /// 握りつぶした例外の内容（成功時は null）。
  final String? error;

  const AutoBackupResult({
    required this.ran,
    this.fileName,
    this.pruned = const <String>[],
    this.error,
  });

  @override
  String toString() =>
      'AutoBackupResult(ran: $ran, fileName: $fileName, '
      'pruned: $pruned, error: $error)';
}

/// 起動時自動バックアップの手順を担うサービス。
///
/// 手順: list → latestCreatedAt → shouldRun → buildJson → write → list →
/// prune → delete。例外は全て握りつぶし [AutoBackupResult.error] に残す
/// （起動経路を絶対に妨げない）。
class AutoBackupService {
  final AutoBackupStore store;
  final AutoBackupPolicy policy;
  final DateTime Function() now;

  /// 試行結果（最終成功・連続失敗）の記録先（null なら記録しない）。
  final AutoBackupStatusStore? statusStore;

  AutoBackupService({
    required this.store,
    this.policy = const AutoBackupPolicy(),
    this.now = DateTime.now,
    this.statusStore,
  });

  /// 保存済みの状態を読み出す（記録先が無ければ null）。
  Future<AutoBackupStatus?> loadStatus() async {
    final store = statusStore;
    if (store == null) return null;
    try {
      return await store.load();
    } catch (_) {
      return null;
    }
  }

  /// 状態の更新を1箇所に集約する（失敗しても本処理を壊さない）。
  Future<void> _record(
    AutoBackupStatus Function(AutoBackupStatus current) update,
  ) async {
    final store = statusStore;
    if (store == null) return;
    try {
      final current = await store.load() ?? AutoBackupStatus.initial;
      await store.save(update(current));
    } catch (_) {
      // 記録の失敗は握る（バックアップ本体の成否とは別問題）。
    }
  }

  /// 自動バックアップを1回分実行する。
  ///
  /// [buildJson] はバックアップ JSON を組み立てる採取関数（既存の
  /// 手動エクスポート経路をそのまま使う想定）。
  Future<AutoBackupResult> run(Future<String> Function() buildJson) async {
    try {
      final entries = await store.list();
      final lastAt = policy.latestCreatedAt(entries);
      final current = now();
      if (!policy.shouldRun(lastAt: lastAt, now: current)) {
        return const AutoBackupResult(ran: false);
      }

      final fileName = AutoBackupPolicy.fileNameFor(current);
      final json = await buildJson();
      await store.write(fileName, json);

      final afterWrite = await store.list();
      final targets = policy.prune(afterWrite);
      final pruned = <String>[];
      for (final entry in targets) {
        await store.delete(entry.fileName);
        pruned.add(entry.fileName);
      }

      await _record((current) => current.recordSuccess(now()));

      return AutoBackupResult(
        ran: true,
        fileName: fileName,
        pruned: List<String>.unmodifiable(pruned),
      );
    } catch (error) {
      await _record((current) => current.recordFailure(now(), error));
      return AutoBackupResult(ran: false, error: '$error');
    }
  }
}
