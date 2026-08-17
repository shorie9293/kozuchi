import 'package:flutter/material.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';
import 'package:kozuchi/features/recurring_transaction/data/recurring_transaction_repository.dart';
import 'package:kozuchi/features/recurring_transaction/domain/recurring_transaction.dart';
import 'package:kozuchi/features/shared/presentation/kozuchi_app_keys.dart';

/// 定期取引管理画面
///
/// 毎日/毎週/毎月の定期取引定義を一覧表示し、追加・削除できる。
/// 定義は [RecurringTransactionRepository] に永続化され、
/// アプリ起動時の自動記録に利用される。
class RecurringTransactionScreen extends StatefulWidget {
  final RecurringTransactionRepository? repository;

  const RecurringTransactionScreen({super.key, this.repository});

  @override
  State<RecurringTransactionScreen> createState() =>
      _RecurringTransactionScreenState();
}

class _RecurringTransactionScreenState extends State<RecurringTransactionScreen> {
  late final RecurringTransactionRepository _repository;
  List<RecurringTransaction> _definitions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? const RecurringTransactionRepository();
    _load();
  }

  Future<void> _load() async {
    final defs = await _repository.loadDefinitions();
    if (mounted) {
      setState(() {
        _definitions = defs;
        _isLoading = false;
      });
    }
  }

  Future<void> _openAddDialog() async {
    final added = await showDialog<RecurringTransaction>(
      context: context,
      builder: (_) => const _RecurringFormDialog(),
    );
    if (added != null) {
      await _repository.addDefinition(added);
      await _load();
    }
  }

  Future<void> _delete(String id) async {
    await _repository.removeDefinition(id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      key: KozuchiAppKeys.recurringTxScreen,
      appBar: AppBar(title: const Text('定期取引')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _definitions.isEmpty
              ? Center(
                  child: Text(
                    '定期取引はまだありません',
                    style: TextStyle(color: colorScheme.outline),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _definitions.length,
                  itemBuilder: (context, index) {
                    final def = _definitions[index];
                    return _buildDefinitionCard(def, colorScheme);
                  },
                ),
      floatingActionButton: SemanticHelper.interactive(
        testId: 'btn_recurringTx_add',
        label: '定期取引を追加',
        child: FloatingActionButton.extended(
          key: KozuchiAppKeys.recurringTx_addButton,
          onPressed: _openAddDialog,
          icon: const Icon(Icons.add),
          label: const Text('定期取引を追加'),
        ),
      ),
    );
  }

  Widget _buildDefinitionCard(
    RecurringTransaction def,
    ColorScheme colorScheme,
  ) {
    final isIncome = def.amount >= 0;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Text(isIncome ? '💰' : '💸'),
        title: Text(def.purpose),
        subtitle: Text(
          '${def.frequency.label}・${_scheduleLabel(def)}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatAmount(def.amount),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isIncome ? Colors.green.shade700 : Colors.red.shade700,
              ),
            ),
            IconButton(
              key: KozuchiAppKeys.recurringTxDeleteButton(def.id),
              tooltip: '削除',
              onPressed: () => _delete(def.id),
              icon: Icon(Icons.delete_outline, color: colorScheme.error),
            ),
          ],
        ),
      ),
    );
  }

  String _scheduleLabel(RecurringTransaction def) {
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    return switch (def.frequency) {
      RecurringFrequency.daily => '毎日',
      RecurringFrequency.weekly => '${weekdays[def.dayOfWeek - 1]}曜日',
      RecurringFrequency.monthly => '毎月${def.dayOfMonth}日',
    };
  }

  String _formatAmount(int amount) {
    final absStr = amount.abs().toString().replaceAllMapped(
          RegExp(r'(\d)(?=(?:\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    return amount >= 0 ? '+¥$absStr' : '-¥$absStr';
  }
}

/// 定期取引追加フォーム
class _RecurringFormDialog extends StatefulWidget {
  const _RecurringFormDialog();

  @override
  State<_RecurringFormDialog> createState() => _RecurringFormDialogState();
}

class _RecurringFormDialogState extends State<_RecurringFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _purposeController;
  late final TextEditingController _amountController;
  late final TextEditingController _dayOfMonthController;
  RecurringFrequency _frequency = RecurringFrequency.monthly;
  int _dayOfWeek = DateTime.monday;

  static const _weekdays = ['月', '火', '水', '木', '金', '土', '日'];

  @override
  void initState() {
    super.initState();
    _purposeController = TextEditingController();
    _amountController = TextEditingController();
    _dayOfMonthController = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _purposeController.dispose();
    _amountController.dispose();
    _dayOfMonthController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final amount = int.parse(_amountController.text.replaceAll(',', ''));
    final dayOfMonth = int.tryParse(_dayOfMonthController.text) ?? 1;

    Navigator.of(context).pop(
      RecurringTransaction(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        purpose: _purposeController.text.trim(),
        category: 'その他',
        amount: amount,
        frequency: _frequency,
        dayOfWeek: _dayOfWeek,
        dayOfMonth: dayOfMonth,
        startDate: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('定期取引を追加'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: KozuchiAppKeys.recurringTx_purposeField,
                controller: _purposeController,
                decoration: const InputDecoration(
                  labelText: '用途（例: 家賃, 給与）',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '用途を入力せよ' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: KozuchiAppKeys.recurringTx_amountField,
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '金額（円）',
                  helperText: '支出はマイナス（例: -85000）',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return '金額を入力せよ';
                  final n = int.tryParse(v.replaceAll(',', ''));
                  if (n == null || n == 0) return '有効な金額を入力せよ';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<RecurringFrequency>(
                key: KozuchiAppKeys.recurringTx_frequencyDropdown,
                value: _frequency,
                decoration: const InputDecoration(
                  labelText: '頻度',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final f in RecurringFrequency.values)
                    DropdownMenuItem(value: f, child: Text(f.label)),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _frequency = v);
                },
              ),
              if (_frequency == RecurringFrequency.weekly) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  key: KozuchiAppKeys.recurringTx_dayOfWeekDropdown,
                  value: _dayOfWeek,
                  decoration: const InputDecoration(
                    labelText: '曜日',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (var i = 1; i <= 7; i++)
                      DropdownMenuItem(
                        value: i,
                        child: Text('${_weekdays[i - 1]}曜日'),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _dayOfWeek = v);
                  },
                ),
              ],
              if (_frequency == RecurringFrequency.monthly) ...[
                const SizedBox(height: 12),
                TextFormField(
                  key: KozuchiAppKeys.recurringTx_dayOfMonthField,
                  controller: _dayOfMonthController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '日（1〜31）',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n < 1 || n > 31) return '1〜31を入力せよ';
                    return null;
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        SemanticHelper.interactive(
          testId: 'btn_recurringTx_save',
          label: '追加する',
          child: ElevatedButton(
            key: KozuchiAppKeys.recurringTx_saveButton,
            onPressed: _submit,
            child: const Text('追加する'),
          ),
        ),
      ],
    );
  }
}
