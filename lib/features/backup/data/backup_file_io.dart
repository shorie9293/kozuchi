import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

/// バックアップJSONの書き出し抽象（テスト差し替え用）。
abstract interface class BackupExporter {
  /// [json] を [fileName] という名前で書き出す／共有する。
  Future<void> export({required String json, required String fileName});
}

/// share_plus を用いた [BackupExporter] 実装。
class SharePlusBackupExporter implements BackupExporter {
  const SharePlusBackupExporter();

  @override
  Future<void> export({required String json, required String fileName}) async {
    final Uint8List bytes = utf8.encode(json);
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            bytes,
            name: fileName,
            mimeType: 'application/json',
          ),
        ],
        fileNameOverrides: [fileName],
      ),
    );
  }
}

/// バックアップJSONの取り込み抽象（テスト差し替え用）。
abstract interface class BackupImporter {
  /// ファイルを選ばせて UTF8 文字列として返す。キャンセル時は null。
  Future<String?> pickJson();
}

/// file_picker を用いた [BackupImporter] 実装。
class FilePickerBackupImporter implements BackupImporter {
  const FilePickerBackupImporter();

  @override
  Future<String?> pickJson() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }
    final bytes = result.files.single.bytes;
    if (bytes == null) {
      return null;
    }
    return utf8.decode(bytes);
  }
}
