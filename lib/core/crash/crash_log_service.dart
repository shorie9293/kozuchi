import 'package:kozuchi/core/crash/crash_log_entry.dart';
import 'package:kozuchi/core/crash/crash_log_repository.dart';

/// 例外を端末内ログへ記録する薄い窓口。
///
/// 記録は投げっぱなし（await しない）で行い、記録自体の失敗は握りつぶす。
/// 「クラッシュを記録する処理がクラッシュを招く」ことを避けるための設計。
class CrashLogger {
  CrashLogger(this.repository);

  final CrashLogRepository repository;

  /// 例外を1件記録する。戻り値は待たなくてよい（テストでは await 可能）。
  Future<void> record(
    Object error,
    StackTrace? stack, {
    CrashKind kind = CrashKind.zoneError,
    DateTime? timestamp,
  }) async {
    try {
      final entry = CrashLogEntry.fromError(
        error,
        stack,
        kind: kind,
        timestamp: timestamp,
      );
      await repository.append(entry);
    } catch (_) {
      // 記録失敗はアプリの挙動に影響させない。
    }
  }
}

/// 直近の記録を要約した「前回の異常終了」文言。0件なら null。
///
/// 例: `前回の異常終了 2件（最終 09:31）`
String? summarize(List<CrashLogEntry> entries, {DateTime? now}) {
  if (entries.isEmpty) return null;
  var latest = entries.first;
  for (final entry in entries) {
    if (entry.timestamp.isAfter(latest.timestamp)) latest = entry;
  }
  final hh = latest.timestamp.hour.toString().padLeft(2, '0');
  final mm = latest.timestamp.minute.toString().padLeft(2, '0');
  return '前回の異常終了 ${entries.length}件（最終 $hh:$mm）';
}

/// 新しい順に [limit] 件だけ返す。
List<CrashLogEntry> recent(
  List<CrashLogEntry> entries, {
  int limit = 5,
}) {
  if (limit <= 0) return const <CrashLogEntry>[];
  final sorted = <CrashLogEntry>[...entries]
    ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  return sorted.take(limit).toList(growable: false);
}
