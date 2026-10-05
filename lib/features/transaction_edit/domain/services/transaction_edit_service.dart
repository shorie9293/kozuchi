import 'package:kozuchi/domain/models/transaction_model.dart';

/// 取引編集の入力検証と編集後取引の組み立てを行う純粋サービス。
///
/// UI（ダイアログ）から独立しており、試練から直接検証できる。
class TransactionEditService {
  const TransactionEditService._();

  /// 金額文字列をパースする。カンマ区切り・全角数字を許容する。
  ///
  /// 0 以下・非数・空文字は null（不正入力）。
  static int? parseAmount(String raw) {
    final normalized = _normalize(raw).replaceAll(',', '');
    if (normalized.isEmpty) return null;
    final value = int.tryParse(normalized);
    if (value == null || value <= 0) return null;
    return value;
  }

  /// 編集結果の [TransactionModel] を組み立てる。
  ///
  /// 不正入力（金額が0以下・空カテゴリ）は null。
  /// [original] の id とレシート画像パスは保持する。
  /// 支出明細由来の取引は金額を負値（支出）として保存する。
  static TransactionModel? buildEdited({
    required TransactionModel original,
    required String amountText,
    required String category,
    required DateTime date,
    required String note,
  }) {
    final amount = parseAmount(amountText);
    if (amount == null) return null;
    final normalizedCategory = _normalize(category);
    if (normalizedCategory.isEmpty) return null;
    final normalizedNote = _normalize(note);
    return original.copyWith(
      amount: original.isIncome ? amount : -amount,
      purpose: normalizedNote.isEmpty || normalizedNote == normalizedCategory
          ? normalizedCategory
          : normalizedNote,
      category: normalizedCategory,
      datetime: date.toIso8601String(),
    );
  }

  /// 全角英数字・全角スペースを半角へ正規化し、前後の空白を除去する。
  static String _normalize(String raw) {
    return raw
        .replaceAll('　', ' ')
        .replaceAllMapped(RegExp(r'[０-９]'), (m) {
          return String.fromCharCode(m[0]!.codeUnitAt(0) - 0xFEE0);
        })
        .trim();
  }
}
