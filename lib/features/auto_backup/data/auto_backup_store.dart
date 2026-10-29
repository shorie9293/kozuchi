import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:kozuchi/features/auto_backup/domain/auto_backup_policy.dart';

/// 自動バックアップファイルの保管庫。
///
/// 実装はファイルシステム（[FileAutoBackupStore]）と、
/// 試練用のインメモリ（[InMemoryAutoBackupStore]）がある。
abstract interface class AutoBackupStore {
  /// 保管庫内の世代一覧（作成時刻つき）。
  Future<List<AutoBackupEntry>> list();

  /// [fileName] へ書き込む（同名は上書き＝同日冪等）。
  Future<void> write(String fileName, String contents);

  /// [fileName] の内容を読み出す（存在しなければ null）。
  Future<String?> read(String fileName);

  /// [fileName] を削除する（存在しなくても例外にしない）。
  Future<void> delete(String fileName);
}

/// 試練・プレビュー用のインメモリ保管庫。
class InMemoryAutoBackupStore implements AutoBackupStore {
  final Map<String, String> _files = <String, String>{};
  final Map<String, DateTime> _createdAt = <String, DateTime>{};
  final DateTime Function() _now;

  InMemoryAutoBackupStore({DateTime Function()? now})
      : _now = now ?? DateTime.now;

  /// 現在保持している内容（ファイル名 → 本文）。
  Map<String, String> get files => Map<String, String>.unmodifiable(_files);

  @override
  Future<List<AutoBackupEntry>> list() async {
    return _files.keys
        .map(
          (name) => AutoBackupEntry(
            fileName: name,
            createdAt: _createdAt[name] ?? _now(),
          ),
        )
        .toList();
  }

  @override
  Future<void> write(String fileName, String contents) async {
    _files[fileName] = contents;
    _createdAt[fileName] = _now();
  }

  @override
  Future<String?> read(String fileName) async => _files[fileName];

  @override
  Future<void> delete(String fileName) async {
    _files.remove(fileName);
    _createdAt.remove(fileName);
  }
}

/// アプリ書類ディレクトリ配下 `auto_backups/` を用いる保管庫。
class FileAutoBackupStore implements AutoBackupStore {
  /// 保存先サブディレクトリ名。
  static const String directoryName = 'auto_backups';

  /// 保存先ディレクトリの解決手段（試練で差し替える）。
  final Future<Directory> Function()? directoryResolver;

  FileAutoBackupStore({this.directoryResolver});

  Future<Directory> _directory() async {
    final resolver = directoryResolver;
    if (resolver != null) return resolver();
    final documents = await getApplicationDocumentsDirectory();
    return Directory(
      '${documents.path}${Platform.pathSeparator}$directoryName',
    );
  }

  @override
  Future<List<AutoBackupEntry>> list() async {
    final directory = await _directory();
    if (!await directory.exists()) return const <AutoBackupEntry>[];
    final entries = <AutoBackupEntry>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (name.isEmpty) continue;
      if (!AutoBackupPolicy.isAutoBackupFile(name)) continue;
      final createdAt = _parseCreatedAt(name) ?? (await entity.stat()).modified;
      entries.add(
        AutoBackupEntry(fileName: name, createdAt: createdAt),
      );
    }
    return entries;
  }

  @override
  Future<void> write(String fileName, String contents) async {
    final directory = await _directory();
    await directory.create(recursive: true);
    final file = File('${directory.path}${Platform.pathSeparator}$fileName');
    await file.writeAsString(contents, flush: true);
  }

  @override
  Future<String?> read(String fileName) async {
    final directory = await _directory();
    final file = File('${directory.path}${Platform.pathSeparator}$fileName');
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  @override
  Future<void> delete(String fileName) async {
    final directory = await _directory();
    final file = File('${directory.path}${Platform.pathSeparator}$fileName');
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// ファイル名の日付（`auto_backup_yyyyMMdd.json`）をローカル暦として解釈する。
  ///
  /// 解釈できない場合は null（呼び出し側は [FileStat.modified] へ退避する）。
  static DateTime? _parseCreatedAt(String fileName) {
    final core = fileName.substring(
      AutoBackupPolicy.filePrefix.length,
      fileName.length - AutoBackupPolicy.fileSuffix.length,
    );
    if (core.length != 8 || int.tryParse(core) == null) return null;
    final year = int.parse(core.substring(0, 4));
    final month = int.parse(core.substring(4, 6));
    final day = int.parse(core.substring(6, 8));
    final parsed = DateTime(year, month, day);
    // 20260231 のような繰り上がりは不正として扱う
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  }
}
