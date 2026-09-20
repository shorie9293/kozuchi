import 'package:flutter/material.dart';

import 'package:kozuchi/features/transaction_filter/presentation/transaction_query_app_keys.dart';

/// 絞込結果のサマリーバー。
///
/// 該当件数・収入合計・支出合計を 1 行で表示する。
/// 例: 「12件 / 収入 ¥3,000 / 支出 ¥8,400」
/// [isEmpty] が true の場合は空状態の文言を表示する。
class TransactionQuerySummaryBar extends StatelessWidget {
  /// 該当件数
  final int count;

  /// 収入合計（正の円）
  final int totalIncome;

  /// 支出合計（正の円）
  final int totalExpense;

  /// 該当 0 件か（true の場合は空状態文言を表示する）
  final bool isEmpty;

  /// フィルタを初期状態に戻すコールバック（null の場合はボタン非表示）
  final VoidCallback? onReset;

  const TransactionQuerySummaryBar({
    super.key,
    required this.count,
    required this.totalIncome,
    required this.totalExpense,
    required this.isEmpty,
    this.onReset,
  });

  /// 金額を ¥1,234,567 形式に整形する
  static String formatYen(int amount) {
    final digits = amount.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return '¥${amount < 0 ? '-' : ''}$buffer';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label: '絞込結果サマリー',
      child: Container(
        key: TransactionQueryAppKeys.summaryBar,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        color: cs.surfaceContainerLow,
        child: Row(
          children: [
            Expanded(
              child: isEmpty
                  ? Text(
                      '該当する取引がありません',
                      key: TransactionQueryAppKeys.resultCount,
                      style: textTheme.bodySmall?.copyWith(
                        color: cs.outline,
                      ),
                    )
                  : Text(
                      '$count件 / 収入 ${formatYen(totalIncome)} / 支出 ${formatYen(totalExpense)}',
                      key: TransactionQueryAppKeys.resultCount,
                      style: textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
            if (onReset != null)
              TextButton(
                key: TransactionQueryAppKeys.resetButton,
                onPressed: onReset,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('リセット'),
              ),
          ],
        ),
      ),
    );
  }
}