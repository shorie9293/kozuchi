import '../models/expense_entry.dart';
import '../models/transaction_model.dart';

/// 支出明細（[ExpenseEntry]）と取引履歴モデル（[TransactionModel]）の変換マッパー。
///
/// 取引履歴の一本化にあたり、Supabase の `expense_entries` を正とし、
/// 履歴画面は支出明細を [TransactionModel] に変換して表示する。
/// 支出は負の金額として表す（収入なし）。
class ExpenseEntryMapper {
  const ExpenseEntryMapper._();

  /// 1件の支出明細を取引モデルへ変換する。
  ///
  /// - amount: 負値（支出）
  /// - purpose: note（未指定ならカテゴリ名）
  /// - category: カテゴリ名
  /// - datetime: ISO 8601
  static TransactionModel toTransactionModel(ExpenseEntry entry) {
    return TransactionModel(
      amount: -entry.amount,
      purpose: entry.note ?? entry.category,
      category: entry.category,
      datetime: entry.date.toIso8601String(),
    );
  }

  /// 複数の支出明細を取引モデルのリストへ一括変換する。
  static List<TransactionModel> toTransactionModels(
    List<ExpenseEntry> entries,
  ) =>
      entries.map(toTransactionModel).toList();
}
