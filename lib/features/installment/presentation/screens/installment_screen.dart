import 'package:flutter/material.dart';

import 'package:kozuchi/features/installment/data/installment_repository.dart';
import 'package:kozuchi/features/installment/domain/installment_service.dart';
import 'package:kozuchi/features/installment/domain/models/installment_plan.dart';
import 'package:kozuchi/features/installment/presentation/installment_app_keys.dart';

/// 分割払いプランの管理画面。
///
/// 残債・残回数・月額を一覧し、返済回数を進めたり削除したりできる。
/// [repository] で永続化先を差し替え可能（試練では SharedPreferences のモックを使用）。
class InstallmentScreen extends StatefulWidget {
  final InstallmentRepository repository;

  const InstallmentScreen({
    super.key,
    this.repository = const InstallmentRepository(),
  });

  @override
  State<InstallmentScreen> createState() => _InstallmentScreenState();
}

class _InstallmentScreenState extends State<InstallmentScreen> {
  List<InstallmentPlan> _plans = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final plans = await widget.repository.loadPlans();
    if (!mounted) return;
    setState(() {
      _plans = plans;
      _isLoading = false;
    });
  }

  Future<void> _addPlan() async {
    final result = await showDialog<_NewPlanValues>(
      context: context,
      builder: (_) => const _AddInstallmentDialog(),
    );
    if (result == null) return;
    final updated = await widget.repository.addPlan(
      purpose: result.purpose,
      category: result.category,
      totalAmount: result.amount,
      installmentCount: result.count,
      startDate: DateTime.now(),
    );
    if (!mounted) return;
    setState(() => _plans = updated);
  }

  Future<void> _incrementPaid(InstallmentPlan plan) async {
    final updated = await widget.repository.incrementPaid(plan.id);
    if (!mounted) return;
    setState(() => _plans = updated);
  }

  Future<void> _deletePlan(InstallmentPlan plan) async {
    final updated = await widget.repository.removePlan(plan.id);
    if (!mounted) return;
    setState(() => _plans = updated);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final remainingTotal = InstallmentService.totalRemainingAmount(_plans);
    return Scaffold(
      key: InstallmentAppKeys.installmentScreen,
      appBar: AppBar(
        title: const Text('分割払い管理'),
        actions: [
          IconButton(
            key: InstallmentAppKeys.installmentAddButton,
            tooltip: '分割払いを追加',
            icon: const Icon(Icons.add),
            onPressed: _addPlan,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSummaryCard(colorScheme, remainingTotal),
                Expanded(
                  child: _plans.isEmpty
                      ? const Center(
                          child: Text(
                            '分割払いはありません',
                            key: InstallmentAppKeys.installmentEmpty,
                          ),
                        )
                      : ListView.builder(
                          itemCount: _plans.length,
                          itemBuilder: (context, index) =>
                              _buildPlanTile(colorScheme, _plans[index]),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryCard(ColorScheme colorScheme, int remainingTotal) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '残債合計',
              style: TextStyle(fontSize: 13, color: colorScheme.outline),
            ),
            const SizedBox(height: 4),
            Text(
              key: InstallmentAppKeys.installmentRemainingTotal,
              _formatYen(remainingTotal),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '毎月の返済額 ${_formatYen(InstallmentService.totalMonthlyInstallmentBurden(_plans))}',
              style: TextStyle(fontSize: 13, color: colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanTile(ColorScheme colorScheme, InstallmentPlan plan) {
    final monthly = InstallmentService.monthlyAmountOf(plan);
    final remaining = InstallmentService.remainingAmount(plan);
    return Semantics(
      label: '分割払い ${plan.purpose}',
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            key: InstallmentAppKeys.installmentTile(plan.id),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      plan.purpose,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (plan.isCompleted)
                    Chip(
                      label: const Text('完済'),
                      backgroundColor: Colors.green.withValues(alpha: 0.15),
                      labelStyle: const TextStyle(fontSize: 12),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '月額 ${_formatYen(monthly)} ・ 残り${plan.remainingCount}回 ・ 残債 ${_formatYen(remaining)}',
                style: TextStyle(fontSize: 13, color: colorScheme.outline),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: plan.progress),
              const SizedBox(height: 4),
              Text(
                '${plan.paidCount}/${plan.installmentCount} 回 返済済み',
                style: TextStyle(fontSize: 12, color: colorScheme.outline),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!plan.isCompleted)
                    TextButton.icon(
                      key: InstallmentAppKeys.installmentPayButton(plan.id),
                      onPressed: () => _incrementPaid(plan),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('1回返済'),
                    ),
                  IconButton(
                    key: InstallmentAppKeys.installmentDeleteButton(plan.id),
                    tooltip: '${plan.purpose} を削除',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deletePlan(plan),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 追加ダイアログの入力値
class _NewPlanValues {
  final String purpose;
  final String category;
  final int amount;
  final int count;

  const _NewPlanValues({
    required this.purpose,
    required this.category,
    required this.amount,
    required this.count,
  });
}

/// 分割払いの追加ダイアログ本体。
///
/// [TextEditingController] の破棄をダイアログ自身のライフサイクルに閉じるため、
/// 独立した [StatefulWidget] としている。
class _AddInstallmentDialog extends StatefulWidget {
  const _AddInstallmentDialog();

  @override
  State<_AddInstallmentDialog> createState() => _AddInstallmentDialogState();
}

class _AddInstallmentDialogState extends State<_AddInstallmentDialog> {
  final _purposeController = TextEditingController();
  final _amountController = TextEditingController();
  final _countController = TextEditingController(text: '12');
  String? _error;

  @override
  void dispose() {
    _purposeController.dispose();
    _amountController.dispose();
    _countController.dispose();
    super.dispose();
  }

  void _submit() {
    final purpose = _purposeController.text.trim();
    final amount = int.tryParse(_amountController.text.trim());
    final count = int.tryParse(_countController.text.trim());
    if (purpose.isEmpty || amount == null || amount < 0) {
      setState(() => _error = '名称と総額を正しく入力してください');
      return;
    }
    if (count == null || count <= 0) {
      setState(() => _error = '分割回数は1以上にしてください');
      return;
    }
    Navigator.of(context).pop(
      _NewPlanValues(
        purpose: purpose,
        category: '分割払い',
        amount: amount,
        count: count,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('分割払いを追加'),
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
              decoration: const InputDecoration(labelText: '総額（円）'),
            ),
            TextField(
              key: InstallmentAppKeys.countField,
              controller: _countController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '分割回数'),
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

/// 円表記（3桁区切り）。
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
