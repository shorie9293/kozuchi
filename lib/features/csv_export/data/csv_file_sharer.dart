import 'dart:convert';

import 'package:share_plus/share_plus.dart';

/// CSV文字列を端末の共有シートへ渡す抽象（試練差し替え用）。
abstract interface class CsvFileSharer {
  Future<void> share({required String csv, required String fileName});
}

/// share_plus を用いた [CsvFileSharer] 実装。
class SharePlusCsvFileSharer implements CsvFileSharer {
  const SharePlusCsvFileSharer();

  @override
  Future<void> share({required String csv, required String fileName}) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            utf8.encode(csv),
            name: fileName,
            mimeType: 'text/csv',
          ),
        ],
        fileNameOverrides: [fileName],
      ),
    );
  }
}
