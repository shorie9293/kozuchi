import 'package:kozuchi/domain/models/transaction_model.dart';

/// 取引検索の結果（該当一覧＋集計）
class TransactionQueryResult {
  /// 該当した取引の一覧（入力順序を保持・変更不可）
  final List<TransactionModel> transactions;

  /// 該当件数
  final int count;

  /// 収入合計（amount >= 0 の合計）
  final int totalIncome;

  /// 支出合計（amount < 0 の絶対値合計・正の値）
  final int totalExpense;

  /// 差引（totalIncome - totalExpense）
  final int net;

  const TransactionQueryResult({
    required this.transactions,
    required this.count,
    required this.totalIncome,
    required this.totalExpense,
    required this.net,
  });

  /// 該当なし
  bool get isEmpty => transactions.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is TransactionQueryResult &&
      count == other.count &&
      totalIncome == other.totalIncome &&
      totalExpense == other.totalExpense &&
      net == other.net &&
      _listEquals(transactions, other.transactions);

  @override
  int get hashCode => Object.hash(
        count,
        totalIncome,
        totalExpense,
        net,
        Object.hashAll(transactions),
      );

  static bool _listEquals(List<TransactionModel> a, List<TransactionModel> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}