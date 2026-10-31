import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:kozuchi/core/crash/crash_log_entry.dart';

/// クラッシュログの保存先を抽象化する。
///
/// 実装は端末内ファイル（[FileCrashLogRepository]）と、
/// 試練用のメモリ実装（[InMemoryCrashLogRepository]）を用意する。
abstract class CrashLogRepository {
  /// 古い順（追記順）で全件を返す。
  Future<List<CrashLogEntry>> loadAll();

  /// 1件追記する。上限を超えた場合は最古から落とす。
  Future<void> append(CrashLogEntry entry);

  /// 全件削除する。
  Future<void> clear();
}

/// documents 配下 `crash_log.jsonl` に 1行1JSON で追記する実装。
///
/// - 壊れた行は読み飛ばす（ログ破損で起動を止めない）。
/// - 直近 [maxEntries] 件でローテートする（端末容量を圧迫しない）。
/// - 書き込み失敗は握りつぶす（クラッシュ記録が二次クラッシュを招かない）。
class FileCrashLogRepository implements CrashLogRepository {
  FileCrashLogRepository({Future<Directory> Function()? directoryProvider})
      : _directoryProvider = directoryProvider;

  /// ログファイル名。
  static const String fileName = 'crash_log.jsonl';

  /// 保持する最大件数。
  static const int maxEntries = 50;

  final Future<Directory> Function()? _directoryProvider;

  Future<File> _file() async {
    final dir = await (_directoryProvider?.call() ??
        getApplicationDocumentsDirectory());
    return File('${dir.path}${Platform.pathSeparator}$fileName');
  }

  @override
  Future<List<CrashLogEntry>> loadAll() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const <CrashLogEntry>[];
      final raw = await file.readAsString();
      final entries = <CrashLogEntry>[];
      for (final line in raw.split('\n')) {
        final entry = CrashLogEntry.tryDecodeLine(line);
        if (entry != null) entries.add(entry);
      }
      return entries;
    } catch (_) {
      // 読み出し不能（権限・破損）でもアプリを止めない。
      return const <CrashLogEntry>[];
    }
  }

  @override
  Future<void> append(CrashLogEntry entry) async {
    try {
      final file = await _file();
      final existing = await loadAll();
      final merged = <CrashLogEntry>[...existing, entry];
      final kept = merged.length > maxEntries
          ? merged.sublist(merged.length - maxEntries)
          : merged;

      // 常に全体を書き直す（1行1JSON + ローテートを1パスで行う）。
      final buffer = StringBuffer();
      for (final e in kept) {
        buffer.writeln(e.encodeLine());
      }
      await file.parent.create(recursive: true);
      await file.writeAsString(buffer.toString(), flush: true);
    } catch (_) {
      // 書込失敗は握る。
    }
  }

  @override
  Future<void> clear() async {
    try {
      final file = await _file();
      if (await file.exists()) await file.delete();
    } catch (_) {
      // 削除失敗は握る。
    }
  }
}

/// メモリ上だけに保持する実装（試練・プレビュー用）。
class InMemoryCrashLogRepository implements CrashLogRepository {
  InMemoryCrashLogRepository([List<CrashLogEntry>? initial])
      : _entries = <CrashLogEntry>[...?initial];

  final List<CrashLogEntry> _entries;

  @override
  Future<List<CrashLogEntry>> loadAll() async =>
      List<CrashLogEntry>.unmodifiable(_entries);

  @override
  Future<void> append(CrashLogEntry entry) async {
    _entries.add(entry);
    if (_entries.length > FileCrashLogRepository.maxEntries) {
      _entries.removeRange(
        0,
        _entries.length - FileCrashLogRepository.maxEntries,
      );
    }
  }

  @override
  Future<void> clear() async => _entries.clear();
}
