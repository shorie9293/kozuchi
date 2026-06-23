import 'package:flutter/material.dart';
import 'package:kozuchi/domain/models/transaction_model.dart';

/// 取引リストの1件を表示するプレゼンテーショナルWidget。
///
/// 収入は緑色、支出は赤色で金額を表示する。
/// 用途・カテゴリ・日時を合わせて表示する。
class TransactionListItem extends StatelessWidget {
  final TransactionModel transaction;

  const TransactionListItem({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isIncome = transaction.isIncome;
    final amountColor = isIncome ? Colors.green.shade700 : Colors.red.shade700;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 金額
            SizedBox(
              width: 100,
              child: Text(
                _formatAmount(transaction.amount),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: amountColor,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 用途・カテゴリ
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.purpose,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildCategoryBadge(transaction.category, colorScheme),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 日時
            Text(
              _formatDatetime(transaction.datetime),
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 金額を ¥ 付きカンマ区切りでフォーマットする。
  /// 収入（正）: ¥1,000  /  支出（負）: -¥1,000
  String _formatAmount(int amount) {
    final absStr = amount.abs().toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    if (amount >= 0) {
      return '¥$absStr';
    } else {
      return '-¥$absStr';
    }
  }

  /// カテゴリを小さなバッジ（Tag）として表示する。
  Widget _buildCategoryBadge(String category, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        category,
        style: TextStyle(
          fontSize: 11,
          color: colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }

  /// ISO 8601 日時文字列を "yyyy/MM/dd HH:mm" 形式に変換する。
  String _formatDatetime(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      final year = dt.year.toString();
      final month = dt.month.toString().padLeft(2, '0');
      final day = dt.day.toString().padLeft(2, '0');
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$year/$month/$day $hour:$minute';
    } catch (_) {
      return isoString;
    }
  }
}
