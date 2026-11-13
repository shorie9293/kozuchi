import 'package:flutter/material.dart';
import 'package:kozuchi/core/format/money_format.dart';
import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/receipt_viewer/presentation/receipt_viewer_app_keys.dart';
import 'package:kozuchi/features/transaction_edit/presentation/transaction_edit_app_keys.dart';

/// 取引履歴の一括選択モードで使う試練用キー。
///
/// 行・チェックボックス・選択バー・確認ダイアログの識別子を一元管理し、
/// 画面とウィジェットで重複しないようにする。
class HistorySelectionKeys {
  HistorySelectionKeys._();

  /// 取引行（Card）のキー。
  static Key item(String id) => Key('history_item_$id');

  /// 選択用チェックボックスのキー。
  static Key checkbox(String id) => Key('history_item_select_$id');

  /// AppBar の「閉じる」（選択モード終了）。
  static const Key close = Key('history_bulk_close');

  /// AppBar の「全選択」。
  static const Key selectAll = Key('history_bulk_select_all');

  /// 選択バーの「削除」。
  static const Key deleteButton = Key('history_bulk_delete');

  /// 選択バーの「解除」。
  static const Key clearButton = Key('history_bulk_clear');

  /// 一括削除確認ダイアログの「削除する」。
  static const Key confirmDelete = Key('history_bulk_confirm_delete');

  /// 一括削除確認ダイアログの「キャンセル」。
  static const Key cancelDelete = Key('history_bulk_cancel_delete');
}

/// 取引リストの1件を表示するプレゼンテーショナルWidget。
///
/// 収入は緑色、支出は赤色で金額を表示する。
/// 用途・カテゴリ・日時を合わせて表示する。
class TransactionListItem extends StatelessWidget {
  final TransactionModel transaction;

  /// タップ時のコールバック（タグ付け導線など）。null なら非タップ。
  final VoidCallback? onTap;

  /// 長押し時のコールバック（一括選択モードの開始）。null なら非対応。
  final VoidCallback? onLongPress;

  /// 一括選択モードで選択されているか（背景色の強調に使う）。
  final bool selected;

  /// 一括選択モードか。true のときのみ先頭にチェックボックスを出す。
  final bool selectionMode;

  /// レシート原本ボタン押下時のコールバック。null なら非タップ。
  final VoidCallback? onReceiptTap;

  /// 編集メニュー選択時のコールバック。null ならメニュー非表示。
  final VoidCallback? onEditTap;

  /// 削除メニュー選択時のコールバック。null ならメニュー非表示。
  final VoidCallback? onDeleteTap;

  const TransactionListItem({
    super.key,
    required this.transaction,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.selectionMode = false,
    this.onReceiptTap,
    this.onEditTap,
    this.onDeleteTap,
  });

  /// 行のキー（ID が無い取引はキー無し＝衝突しない）。
  Key? get _rowKey {
    final id = transaction.id;
    if (id == null || id.isEmpty) return null;
    return HistorySelectionKeys.item(id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isIncome = transaction.isIncome;
    final amountColor = isIncome ? Colors.green.shade700 : Colors.red.shade700;

    return Card(
      key: _rowKey,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: selected ? colorScheme.primaryContainer : null,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: _buildRow(colorScheme, amountColor),
        ),
      ),
    );
  }

  Widget _buildRow(ColorScheme colorScheme, Color amountColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 一括選択モード時のみ選択チェックボックスを表示
        if (selectionMode)
          SizedBox(
            width: 40,
            height: 40,
            child: Checkbox(
              key: HistorySelectionKeys.checkbox(
                transaction.id ?? '',
              ),
              value: selected,
              onChanged: onTap == null ? null : (_) => onTap!.call(),
            ),
          ),
        // 金額
        SizedBox(
          width: 100,
          child: Text(
            formatYen(transaction.amount),
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
        // レシート原本ボタン（パスがある場合のみ表示）
        if ((transaction.receiptImagePath ?? '').trim().isNotEmpty)
          IconButton(
            key: ReceiptViewerAppKeys.receiptButtonFor(
              transaction.datetime,
              transaction.amount,
            ),
            tooltip: 'レシート原本を見る',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: onReceiptTap,
          ),
        // 訂正メニュー（編集・削除）。コールバックが1つでもあれば表示。
        if (onEditTap != null || onDeleteTap != null)
          PopupMenuButton<String>(
            key: TransactionEditAppKeys.menuFor(
              transaction.datetime,
              transaction.amount,
            ),
            tooltip: '取引を訂正',
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'edit') {
                onEditTap?.call();
              } else if (value == 'delete') {
                onDeleteTap?.call();
              }
            },
            itemBuilder: (context) => [
              if (onEditTap != null)
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('編集'),
                  ),
                ),
              if (onDeleteTap != null)
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline),
                    title: Text('削除'),
                  ),
                ),
            ],
          ),
      ],
    );
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
  ///
  /// クラウド由来の Z 付き文字列でも**ローカル時刻**で表示する
  /// （UTC のまま組むと JST 早朝の取引が前日 23:xx に見える）。
  String _formatDatetime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
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
