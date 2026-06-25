/// クエスト進捗検出のためのユーザーアクション型
///
/// ユーザーの行動を表す sealed なアクション型。
/// [QuestProgressDetector] がこれを受け取り、
/// アクティブなデイリークエストの進捗を更新する。
sealed class QuestAction {
  const QuestAction();

  /// 支出が記録された
  ///
  /// [amount] 支出金額（円、正の整数）
  /// [category] 支出カテゴリ名（例: '食費', '書籍', '交通費'）
  const factory QuestAction.expenseRecorded({
    required int amount,
    required String category,
  }) = ExpenseRecorded;

  /// レシートが撮影された
  const factory QuestAction.receiptScanned() = ReceiptScanned;

  /// 新規カテゴリが使用された
  ///
  /// [category] 新しく使われたカテゴリ名
  const factory QuestAction.newCategoryUsed({
    required String category,
  }) = NewCategoryUsed;
}

/// 支出記録アクション
class ExpenseRecorded extends QuestAction {
  final int amount;
  final String category;

  const ExpenseRecorded({
    required this.amount,
    required this.category,
  }) : assert(amount > 0, 'amount must be positive');
}

/// レシート撮影アクション
class ReceiptScanned extends QuestAction {
  const ReceiptScanned();
}

/// 新規カテゴリ使用アクション
class NewCategoryUsed extends QuestAction {
  final String category;

  const NewCategoryUsed({
    required this.category,
  });
}
