import 'package:flutter/material.dart';
import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/transaction_history/presentation/widgets/transaction_list_item.dart';

/// 取引一覧を表示するスクロール可能なリストWidget。
///
/// 3つの表示状態をpropsで制御する：
/// - **ローディング中**（`isLoading = true`）: スケルトンプレースホルダーを表示
/// - **エラー**（`errorMessage != null`）: エラーメッセージ＋リトライボタン
/// - **空**（`transactions` が空かつロード完了・エラーなし）: 「取引がありません」
/// - **リスト**（上記いずれでもない）: [TransactionListItem] で各取引を表示
///
/// 大量の取引でも [ListView.builder] で仮想化され、メモリ効率が良い。
class TransactionListWidget extends StatelessWidget {
  /// 表示する取引リスト。
  final List<TransactionModel> transactions;

  /// ローディング中かどうか。
  final bool isLoading;

  /// エラーメッセージ。null でなければエラー表示に切り替わる。
  final String? errorMessage;

  /// リトライボタン押下時のコールバック。
  final VoidCallback? onRetry;

  const TransactionListWidget({
    super.key,
    this.transactions = const [],
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    // ローディング中
    if (isLoading) {
      return _buildLoadingSkeleton(context);
    }

    // エラー
    if (errorMessage != null) {
      return _buildErrorView(context);
    }

    // 空
    if (transactions.isEmpty) {
      return _buildEmptyView(context);
    }

    // リスト表示
    return _buildListView(context);
  }

  /// スケルトンプレースホルダー（ローディング表示）。
  ///
  /// 実際のリスト項目の高さと形状を模した3件の灰色バーを表示する。
  Widget _buildLoadingSkeleton(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // 金額スケルトン
                Container(
                  width: 80,
                  height: 18,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                // 用途スケルトン
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 14,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 80,
                        height: 12,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 日時スケルトン
                Container(
                  width: 100,
                  height: 12,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// エラー表示。
  ///
  /// 中央にエラーメッセージとリトライボタンを表示する。
  Widget _buildErrorView(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.error,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('再試行'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 空リスト表示。
  ///
  /// 取引が一件もない状態を表すメッセージを中央に表示する。
  Widget _buildEmptyView(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: theme.colorScheme.outline.withAlpha(128),
          ),
          const SizedBox(height: 16),
          Text(
            '取引がありません',
            style: TextStyle(
              fontSize: 16,
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  /// 取引一覧（[ListView.builder] で仮想化）。
  ///
  /// パフォーマンスのため、アイテム数が多くても必要な分だけビルドする。
  Widget _buildListView(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        return TransactionListItem(
          transaction: transactions[index],
        );
      },
    );
  }
}
