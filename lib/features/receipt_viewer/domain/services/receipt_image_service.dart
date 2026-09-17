import 'package:kozuchi/features/receipt_viewer/domain/models/receipt_image_ref.dart';

/// レシート画像の利用可否状態。
enum ReceiptImageAvailability {
  /// 利用可能。
  available,

  /// ファイルが存在しない。
  missingFile,

  /// パスが不正。
  invalidPath,

  /// 非対応の画像形式。
  unsupportedFormat,

  /// 対象なし（パス未設定）。
  none,
}

/// [ReceiptImageAvailability] の日本語ラベルを返す。
String receiptAvailabilityLabel(ReceiptImageAvailability availability) {
  switch (availability) {
    case ReceiptImageAvailability.available:
      return '利用可能';
    case ReceiptImageAvailability.missingFile:
      return 'ファイルが見つかりません';
    case ReceiptImageAvailability.invalidPath:
      return 'パスが不正です';
    case ReceiptImageAvailability.unsupportedFormat:
      return '非対応の画像形式です';
    case ReceiptImageAvailability.none:
      return 'レシート画像なし';
  }
}

/// レシート画像の状態判定を行う純粋サービス（I/O なし）。
///
/// [fileChecker] を指定した場合のみ実在確認を行う
/// （未指定ならファイルは存在するものとして扱う）。
class ReceiptImageService {
  /// 実在確認関数（テストで差し替え可能）。null なら確認しない。
  final Future<bool> Function(String path)? fileChecker;

  const ReceiptImageService({this.fileChecker});

  /// [rawPath] の状態を判定する。例外は投げない。
  Future<ReceiptImageAvailability> check(String? rawPath) async {
    if (rawPath == null || rawPath.trim().isEmpty) {
      return ReceiptImageAvailability.none;
    }
    final ref = ReceiptImageRef.tryFromPath(rawPath);
    if (ref == null) {
      return ReceiptImageAvailability.invalidPath;
    }
    if (!ref.isSupportedImage) {
      return ReceiptImageAvailability.unsupportedFormat;
    }
    final checker = fileChecker;
    if (checker != null) {
      final exists = await checker(ref.path);
      if (!exists) {
        return ReceiptImageAvailability.missingFile;
      }
    }
    return ReceiptImageAvailability.available;
  }

  /// [paths] のうち有効なレシートパスの件数。
  int countWithReceipt(List<String?> paths) {
    var count = 0;
    for (final path in paths) {
      if (ReceiptImageRef.tryFromPath(path) != null) {
        count++;
      }
    }
    return count;
  }

  /// [paths] のうち1件でも有効なレシートパスがあるか。
  bool hasAnyReceipt(List<String?> paths) => countWithReceipt(paths) > 0;

  /// 表示用の説明文。null/空 なら 'レシート画像なし'。
  String describe(String? rawPath) {
    final ref = ReceiptImageRef.tryFromPath(rawPath);
    if (ref == null) {
      return 'レシート画像なし';
    }
    return 'レシート原本: ${ref.fileName}';
  }

  /// trim 済み有効パスの一覧（順序保持・重複除去）。
  List<String> validPaths(List<String?> paths) {
    final result = <String>[];
    for (final path in paths) {
      final ref = ReceiptImageRef.tryFromPath(path);
      if (ref != null && !result.contains(ref.path)) {
        result.add(ref.path);
      }
    }
    return result;
  }
}
