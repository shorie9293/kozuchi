import 'package:flutter/material.dart';

import 'package:kozuchi/features/installment/data/installment_repository.dart';
import 'package:kozuchi/features/installment/domain/installment_service.dart';
import 'package:kozuchi/features/installment/domain/models/subscription.dart';
import 'package:kozuchi/features/installment/presentation/installment_app_keys.dart';

/// サブスクリプション（定額課金）の管理画面。
///
/// 月額合計・年額・次回請求日を一覧し、有効/無効の切替や削除ができる。
/// [repository] で永続化先を差し替え可能（試練では SharedPreferences のモックを使用）。
class SubscriptionScreen extends StatefulWidget {
  final InstallmentRepository repository;

  const SubscriptionScreen({
    super.key,
    this.repository = const InstallmentRepository(),
  });

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  List<Subscription> _subscriptions = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final subs = await widget.repository.loadSubscriptions();
    if (!mounted) return;
    setState(() {
      _subscriptions = subs;
      _isLoading = false;
    });
  }

  Future<void> _addSubscription() async {
    final result = await showDialog<_NewSubscriptionValues>(
      context: context,
      builder: (_) => const _AddSubscriptionDialog(),
    );
    if (result == null) return;
    final updated = await widget.repository.addSubscription(
      purpose: result.purpose,
      category: 'サブスク',
      amount: result.amount,
      billingDay: result.billingDay,
      startDate: DateTime.now(),
    );
    if (!mounted) return;
    setState(() => _subscriptions = updated);
  }

  Future<void> _toggle(Subscription sub) async {
    final updated = await widget.repository.toggleSubscription(sub.id);
    if (!mounted) return;
    setState(() => _subscriptions = updated);
  }

  Future<void> _delete(Subscription sub) async {
    final updated = await widget.repository.removeSubscription(sub.id);
    if (!mounted) return;
    setState(() => _subscriptions = updated);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final monthlyTotal =
        InstallmentService.subscriptionMonthlyTotal(_subscriptions);
    return Scaffold(
      key: InstallmentAppKeys.subscriptionScreen,
      appBar: AppBar(
        title: const Text('サブスク管理'),
        actions: [
          IconButton(
            key: InstallmentAppKeys.subscriptionAddButton,
            tooltip: 'サブスクを追加',
            icon: const Icon(Icons.add),
            onPressed: _addSubscription,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSummaryCard(colorScheme, monthlyTotal),
                Expanded(
                  child: _subscriptions.isEmpty
                      ? const Center(
                          child: Text(
                            'サブスクはありません',
                            key: InstallmentAppKeys.subscriptionEmpty,
                          ),
                        )
                      : ListView.builder(
                          itemCount: _subscriptions.length,
                          itemBuilder: (context, index) =>
                              _buildTile(colorScheme, _subscriptions[index]),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryCard(ColorScheme colorScheme, int monthlyTotal) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '月額合計',
              style: TextStyle(fontSize: 13, color: colorScheme.outline),
            ),
            const SizedBox(height: 4),
            Text(
              key: InstallmentAppKeys.subscriptionMonthlyTotal,
              _formatYen(monthlyTotal),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '年額 ${_formatYen(monthlyTotal * 12)}',
              style: TextStyle(fontSize: 13, color: colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(ColorScheme colorScheme, Subscription sub) {
    final next = InstallmentService.nextBillingDate(sub);
    return Semantics(
      label: 'サブスク ${sub.purpose}',
      child: ListTile(
        key: InstallmentAppKeys.subscriptionTile(sub.id),
        title: Text(sub.purpose),
        subtitle: Text(
          '月額 ${_formatYen(sub.amount)} ・ 毎月${sub.billingDay}日 ・ 次回 ${_formatDate(next)}',
          style: TextStyle(
            fontSize: 12,
            color: sub.isActive ? colorScheme.outline : colorScheme.outline.withValues(alpha: 0.6),
          ),
        ),
        leading: CircleAvatar(
          radius: 14,
          backgroundColor:
              (sub.isActive ? Colors.blue : Colors.grey).withValues(alpha: 0.2),
          child: Icon(
            Icons.autorenew,
            size: 16,
            color: sub.isActive ? Colors.blue : Colors.grey,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              key: InstallmentAppKeys.subscriptionToggle(sub.id),
              value: sub.isActive,
              onChanged: (_) => _toggle(sub),
            ),
            IconButton(
              key: InstallmentAppKeys.subscriptionDeleteButton(sub.id),
              tooltip: '${sub.purpose} を削除',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(sub),
            ),
          ],
        ),
      ),
    );
  }
}

/// 追加ダイアログの入力値
class _NewSubscriptionValues {
  final String purpose;
  final int amount;
  final int billingDay;

  const _NewSubscriptionValues({
    required this.purpose,
    required this.amount,
    required this.billingDay,
  });
}

/// サブスクの追加ダイアログ本体。
class _AddSubscriptionDialog extends StatefulWidget {
  const _AddSubscriptionDialog();

  @override
  State<_AddSubscriptionDialog> createState() => _AddSubscriptionDialogState();
}

class _AddSubscriptionDialogState extends State<_AddSubscriptionDialog> {
  final _purposeController = TextEditingController();
  final _amountController = TextEditingController();
  final _dayController = TextEditingController(text: '1');
  String? _error;

  @override
  void dispose() {
    _purposeController.dispose();
    _amountController.dispose();
    _dayController.dispose();
    super.dispose();
  }

  void _submit() {
    final purpose = _purposeController.text.trim();
    final amount = int.tryParse(_amountController.text.trim());
    final day = int.tryParse(_dayController.text.trim());
    if (purpose.isEmpty || amount == null || amount < 0) {
      setState(() => _error = '名称と月額を正しく入力してください');
      return;
    }
    if (day == null || day < 1 || day > 31) {
      setState(() => _error = '請求日は1〜31で入力してください');
      return;
    }
    Navigator.of(context).pop(
      _NewSubscriptionValues(purpose: purpose, amount: amount, billingDay: day),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('サブスクを追加'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: InstallmentAppKeys.purposeField,
              controller: _purposeController,
              autofocus: true,
              decoration: const InputDecoration(labelText: '名称'),
            ),
            TextField(
              key: InstallmentAppKeys.amountField,
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '月額（円）'),
            ),
            TextField(
              key: InstallmentAppKeys.countField,
              controller: _dayController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '毎月の請求日（1〜31）'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          key: InstallmentAppKeys.dialogSaveButton,
          onPressed: _submit,
          child: const Text('保存'),
        ),
      ],
    );
  }
}

String _formatYen(int amount) {
  final negative = amount < 0;
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '${negative ? '-' : ''}¥$buffer';
}

String _formatDate(DateTime date) =>
    '${date.month}/${date.day}';
