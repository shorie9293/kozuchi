import 'package:flutter/material.dart';

import 'package:kozuchi/features/wallet/data/wallet_repository.dart';
import 'package:kozuchi/features/wallet/domain/models/wallet.dart';
import 'package:kozuchi/features/wallet/domain/models/wallet_movement.dart';
import 'package:kozuchi/features/wallet/presentation/wallet_app_keys.dart';

/// 1つの財布の入出金履歴を表示し、記録・削除する画面。
class WalletMovementsScreen extends StatefulWidget {
  final WalletRepository repository;
  final Wallet wallet;

  const WalletMovementsScreen({
    super.key,
    this.repository = const WalletRepository(),
    required this.wallet,
  });

  @override
  State<WalletMovementsScreen> createState() => _WalletMovementsScreenState();
}

class _WalletMovementsScreenState extends State<WalletMovementsScreen> {
  List<WalletMovement> _movements = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final movements = await widget.repository.movementsFor(widget.wallet.id);
    if (!mounted) return;
    setState(() {
      _movements = movements;
      _isLoading = false;
    });
  }

  int get _income =>
      _movements.fold(0, (sum, m) => m.isIncome ? sum + m.amount : sum);

  int get _expense =>
      _movements.fold(0, (sum, m) => m.isExpense ? sum - m.amount : sum);

  int get _balance => widget.wallet.initialBalance + _income - _expense;

  Future<void> _addMovement() async {
    final draft = await showDialog<_MovementDraft>(
      context: context,
      builder: (_) => const MovementDialog(),
    );
    if (draft == null) return;

    await widget.repository.addMovement(
      walletId: widget.wallet.id,
      amount: draft.isIncome ? draft.amount : -draft.amount,
      note: draft.note,
      date: DateTime.now(),
    );
    await _load();
  }

  Future<void> _deleteMovement(WalletMovement movement) async {
    final updated = await widget.repository.removeMovement(movement.id);
    if (!mounted) return;
    setState(() {
      _movements = updated
          .where((m) => m.walletId == widget.wallet.id)
          .toList(growable: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: WalletAppKeys.movementsScreen,
      appBar: AppBar(
        title: Text(widget.wallet.name),
        actions: [
          IconButton(
            key: WalletAppKeys.movementAddButton,
            tooltip: '入出金を記録',
            icon: const Icon(Icons.add),
            onPressed: _addMovement,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Card(
                  margin: const EdgeInsets.all(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '現在残高',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        Text(
                          formatYen(_balance),
                          key: WalletAppKeys.movementsBalance,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: _movements.isEmpty
                      ? const Center(
                          key: WalletAppKeys.movementsEmpty,
                          child: Text('入出金の記録がありません'),
                        )
                      : ListView.builder(
                          itemCount: _movements.length,
                          itemBuilder: (context, index) {
                            final movement = _movements[index];
                            final label = movement.note.isEmpty
                                ? (movement.isIncome ? '入金' : '出金')
                                : movement.note;
                            return Semantics(
                              label: '$label '
                                  '${formatYenSigned(movement.amount)}',
                              child: ListTile(
                                key: WalletAppKeys.movementTile(movement.id),
                                title: Text(label),
                                subtitle: Text(formatDate(movement.date)),
                                trailing: SizedBox(
                                  width: 140,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          formatYenSigned(movement.amount),
                                          textAlign: TextAlign.end,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: movement.isIncome
                                                ? Colors.green.shade700
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .error,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        key: WalletAppKeys.movementDeleteButton(
                                          movement.id,
                                        ),
                                        tooltip: '$label を削除',
                                        icon: const Icon(
                                          Icons.delete_outline,
                                        ),
                                        onPressed: () =>
                                            _deleteMovement(movement),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

/// 入出金ダイアログの入力内容
class _MovementDraft {
  final int amount;
  final bool isIncome;
  final String note;

  const _MovementDraft({
    required this.amount,
    required this.isIncome,
    required this.note,
  });
}

/// 入出金記録ダイアログ本体（独立 [StatefulWidget] としてライフサイクルを閉じる）。
class MovementDialog extends StatefulWidget {
  const MovementDialog({super.key});

  @override
  State<MovementDialog> createState() => _MovementDialogState();
}

class _MovementDialogState extends State<MovementDialog> {
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  bool _isIncome = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = int.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = '金額は1円以上で入力してください');
      return;
    }
    Navigator.of(context).pop(
      _MovementDraft(
        amount: amount,
        isIncome: _isIncome,
        note: _noteController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('入出金を記録'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ChoiceChip(
                key: WalletAppKeys.incomeChoice,
                label: const Text('入金'),
                selected: _isIncome,
                onSelected: (_) => setState(() => _isIncome = true),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                key: WalletAppKeys.expenseChoice,
                label: const Text('出金'),
                selected: !_isIncome,
                onSelected: (_) => setState(() => _isIncome = false),
              ),
            ],
          ),
          TextField(
            key: WalletAppKeys.amountField,
            controller: _amountController,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '金額（円）'),
          ),
          TextField(
            key: WalletAppKeys.noteField,
            controller: _noteController,
            decoration: const InputDecoration(labelText: 'メモ（任意）'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                key: WalletAppKeys.movementDialogError,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          key: WalletAppKeys.movementSaveButton,
          onPressed: _submit,
          child: const Text('保存'),
        ),
      ],
    );
  }
}
