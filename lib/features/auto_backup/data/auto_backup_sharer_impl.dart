import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:kozuchi/features/auto_backup/domain/auto_backup_sharer.dart';

/// share_plus を用いた [AutoBackupSharer] 実装。
///
/// 内容を一時ディレクトリへ書き出してから共有する
/// （`backup_file_io.dart` の Share 経路に倣う）。
class SharePlusAutoBackupSharer implements AutoBackupSharer {
  /// 一時ディレクトリの解決手段（試練で差し替える）。
  final Future<Directory> Function() directoryResolver;

  SharePlusAutoBackupSharer({Future<Directory> Function()? directoryResolver})
      : directoryResolver = directoryResolver ?? getTemporaryDirectory;

  @override
  Future<void> share(String fileName, String json) async {
    final directory = await directoryResolver();
    final file = File('${directory.path}${Platform.pathSeparator}$fileName');
    await file.writeAsString(json, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        fileNameOverrides: [fileName],
      ),
    );
  }
}
