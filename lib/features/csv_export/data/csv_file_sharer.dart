import 'package:kozuchi/features/csv_export/domain/csv_bytes.dart';
import 'package:share_plus/share_plus.dart';

/// CSV文字列を端末の共有シートへ渡す抽象（試練差し替え用）。
abstract interface class CsvFileSharer {
  Future<void> share({required String csv, required String fileName});
}

/// share_plus を用いた [CsvFileSharer] 実装。
///
/// 共有するバイト列は **BOM付きUTF-8** にする（Excelでの日本語化け対策）。
/// 文字列を受け取る契約（[CsvFileSharer]）は BOM 無しのまま保つ。
class SharePlusCsvFileSharer implements CsvFileSharer {
  const SharePlusCsvFileSharer();

  @override
  Future<void> share({required String csv, required String fileName}) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            csvBytes(csv),
            name: fileName,
            mimeType: 'text/csv',
          ),
        ],
        fileNameOverrides: [fileName],
      ),
    );
  }
}
