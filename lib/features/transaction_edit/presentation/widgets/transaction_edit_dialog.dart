import 'package:flutter/material.dart';

import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/transaction_edit/domain/services/transaction_edit_service.dart';
import 'package:kozuchi/features/transaction_edit/presentation/transaction_edit_app_keys.dart';

/// 取引の編集ダイアログ（金額・カテゴリ・日付・メモ）。
///
/// 保存で編集後の [TransactionModel]、キャンセル・破棄で null を返す。
/// 支出（負値）の場合は入力欄に絶対値を表示し、保存時に負号を復元する。
class TransactionEditDialog extends StatefulWidget {
  /// 編集対象の取引。
  final TransactionModel transaction;

  /// 日付選択の下限（フィルタ範囲など）。null なら 2000年。
  final DateTime? firstDate;

  /// 日付選択の上限。null なら 2100年。
  final DateTime? lastDate;

  const TransactionEditDialog({
    super.key,
    required this.transaction,
    this.firstDate,
    this.lastDate,
  });

  /// ダイアログを開き、編集結果（保存時）または null を返す。
  static Future<TransactionModel?> show(
    BuildContext context, {
    required TransactionModel transaction,
    DateTime? firstDate,
    DateTime? lastDate,
  }) {
    return showDialog<TransactionModel>(
      context: context,
      builder: (_) => TransactionEditDialog(
        transaction: transaction,
        firstDate: firstDate,
        lastDate: lastDate,
      ),
    );
  }

  @override
  State<TransactionEditDialog> createState() => _TransactionEditDialogState();
}

class _TransactionEditDialogState extends State<TransactionEditDialog> {
  late final TextEditingController _amountController;
  late final TextEditingController _categoryController;
  late final TextEditingController _noteController;
  late DateTime _date;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final tx = widget.transaction;
    _amountController = TextEditingController(text: '${tx.absAmount}');
    _categoryController = TextEditingController(text: tx.category);
    _noteController =
        TextEditingController(text: tx.purpose == tx.category ? '' : tx.purpose);
    _date = DateTime.tryParse(tx.datetime) ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _categoryController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: widget.firstDate ?? DateTime(2000),
      lastDate: widget.lastDate ?? DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _date = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _date.hour,
          _date.minute,
        );
      });
    }
  }

  void _save() {
    final edited = TransactionEditService.buildEdited(
      original: widget.transaction,
      amountText: _amountController.text,
      category: _categoryController.text,
      date: _date,
      note: _noteController.text,
    );
    if (edited == null) {
      setState(() {
        _errorText = '金額は1以上の数値・カテゴリは必須です';
      });
      return;
    }
    Navigator.of(context).pop(edited);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('取引を編集'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: TransactionEditAppKeys.amountField,
              controller: _amountController,
              decoration: InputDecoration(
                labelText: '金額（円）',
                errorText: _errorText,
              ),
              keyboardType: TextInputType.number,
            ),
            TextField(
              key: TransactionEditAppKeys.categoryField,
              controller: _categoryController,
              decoration: const InputDecoration(labelText: 'カテゴリ'),
            ),
            TextField(
              key: TransactionEditAppKeys.noteField,
              controller: _noteController,
              decoration: const InputDecoration(labelText: 'メモ'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              key: TransactionEditAppKeys.dateButton,
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_month),
              label: Text(_formatDate(_date)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: TransactionEditAppKeys.cancelButton,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          key: TransactionEditAppKeys.saveButton,
          onPressed: _save,
          child: const Text('保存'),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    return '${dt.year}/$month/$day';
  }
}

/// 取引の削除確認ダイアログ。確定で true、取消・破棄で false を返す。
Future<bool> showTransactionDeleteConfirmDialog(
  BuildContext context, {
  required TransactionModel transaction,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('取引を削除'),
      content: Text('この取引（${transaction.purpose} / ${transaction.absAmount}円）を削除しますか？'),
      actions: [
        TextButton(
          key: TransactionEditAppKeys.deleteCancelButton,
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          key: TransactionEditAppKeys.deleteConfirmButton,
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('削除する'),
        ),
      ],
    ),
  );
  return result ?? false;
}
