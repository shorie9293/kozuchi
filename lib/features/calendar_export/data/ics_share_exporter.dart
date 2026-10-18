import 'dart:convert';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// ICS 書き出しの抽象（テスト差し替え用）。
abstract interface class IcsShareExporter {
  /// [ics] を [fileName] という名前で書き出す／共有する。
  Future<void> export({required String ics, required String fileName});
}

/// share_plus を用いた [IcsShareExporter] 実装。
class SharePlusIcsShareExporter implements IcsShareExporter {
  const SharePlusIcsShareExporter();

  @override
  Future<void> export({required String ics, required String fileName}) async {
    final Uint8List bytes = utf8.encode(ics);
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            bytes,
            name: fileName,
            mimeType: 'text/calendar',
          ),
        ],
        fileNameOverrides: [fileName],
      ),
    );
  }
}
