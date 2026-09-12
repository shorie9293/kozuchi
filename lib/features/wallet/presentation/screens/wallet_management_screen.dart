import 'package:flutter/material.dart';

import 'package:kozuchi/features/wallet/data/wallet_repository.dart';
import 'package:kozuchi/features/wallet/domain/models/wallet.dart';
import 'package:kozuchi/features/wallet/domain/models/wallet_movement.dart';
import 'package:kozuchi/features/wallet/domain/wallet_service.dart';
import 'package:kozuchi/features/wallet/presentation/screens/wallet_movements_screen.dart';
import 'package:kozuchi/features/wallet/presentation/wallet_app_keys.dart';

/// 複数の財布（現金・銀行口座・電子マネー等）を管理し、財布別の残高を俯瞰する画面。
///
/// [repository] で永続化先を差し替え可能（試練では SharedPreferences のモックを使用）。
class WalletManagementScreen extends StatefulWidget {
  final WalletRepository repository;

  const WalletManagementScreen({
    super.key,
    this.repository = const WalletRepository(),
  });

  @override
  State<WalletManagementScreen> createState() => _WalletManagementScreenState();
}

class _WalletManagementScreenState extends State<WalletManagementScreen> {
  List<Wallet> _wallets = const [];
  List<WalletMovement> _movements = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final wallets = await widget.repository.loadWallets();
    final movements = await widget.repository.loadMovements();
    if (!mounted) return;
    setState(() {
      _wallets = wallets;
      _movements = movements;
      _isLoading = false;
    });
  }

  WalletSummary get _summary =>
      WalletService.compute(wallets: _wallets, movements: _movements);

  Future<void> _addWallet() async {
    final result = await showDialog<_WalletDraft>(
      context: context,
      builder: (_) => const WalletDialog(),
    );
    if (result == null) return;

    final updated = await widget.repository.addWallet(
      name: result.name,
      type: result.type,
      initialBalance: result.initialBalance,
    );
    if (!mounted) return;
    setState(() => _wallets = updated);
  }

  Future<void> _deleteWallet(Wallet wallet) async {
    final updated = await widget.repository.removeWallet(wallet.id);
    final movements = await widget.repository.loadMovements();
    if (!mounted) return;
    setState(() {
      _wallets = updated;
      _movements = movements;
    });
  }

  Future<void> _openMovements(Wallet wallet) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WalletMovementsScreen(
          repository: widget.repository,
          wallet: wallet,
        ),
      ),
    );
    await _load();
  }

  int _movementCountOf(String walletId) =>
      _movements.where((m) => m.walletId == walletId).length;

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    return Scaffold(
      key: WalletAppKeys.managementScreen,
      appBar: AppBar(
        title: const Text('財布・口座'),
        actions: [
          IconButton(
            key: WalletAppKeys.addButton,
            tooltip: '財布を追加',
            icon: const Icon(Icons.add),
            onPressed: _addWallet,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _TotalCard(summary: summary),
                Expanded(
                  child: _wallets.isEmpty
                      ? const Center(
                          key: WalletAppKeys.empty,
                          child: Text('財布がありません'),
                        )
                      : ListView.builder(
                          itemCount: summary.balances.length,
                          itemBuilder: (context, index) {
                            final entry = summary.balances[index];
                            final wallet = entry.wallet;
                            return Semantics(
                              label: '財布 ${wallet.name} 残高 '
                                  '${formatYen(entry.balance)}',
                              child: ListTile(
                                key: WalletAppKeys.listTile(wallet.id),
                                leading: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Color(wallet.colorValue),
                                ),
                                title: Text(wallet.name),
                                subtitle: Text(
                                  '${wallet.type.label}・入出金'
                                  '${_movementCountOf(wallet.id)}件',
                                  key: WalletAppKeys.movementsCount(wallet.id),
                                ),
                                trailing: SizedBox(
                                  width: 140,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          formatYen(entry.balance),
                                          key: WalletAppKeys.balanceText(
                                            wallet.id,
                                          ),
                                          textAlign: TextAlign.end,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: entry.isNegative
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .error
                                                : null,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        key: WalletAppKeys.deleteButton(
                                          wallet.id,
                                        ),
                                        tooltip: '${wallet.name} を削除',
                                        icon: const Icon(
                                          Icons.delete_outline,
                                        ),
                                        onPressed: () =>
                                            _deleteWallet(wallet),
                                      ),
                                    ],
                                  ),
                                ),
                                onTap: () => _openMovements(wallet),
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

/// 合計残高カード
class _TotalCard extends StatelessWidget {
  final WalletSummary summary;

  const _TotalCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: WalletAppKeys.totalCard,
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('合計残高', style: theme.textTheme.labelMedium),
            Text(
              formatYen(summary.totalBalance),
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '財布 ${summary.balances.length}件・入金 '
              '${formatYen(summary.totalIncome)}・出金 '
              '${formatYen(summary.totalExpense)}',
              style: theme.textTheme.bodySmall,
            ),
            if (summary.negativeWallets.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '残高マイナス: '
                '${summary.negativeWallets.map((e) => e.wallet.name).join('・')}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 財布追加ダイアログの入力内容
class _WalletDraft {
  final String name;
  final WalletType type;
  final int initialBalance;

  const _WalletDraft({
    required this.name,
    required this.type,
    required this.initialBalance,
  });
}

/// 財布追加ダイアログ本体。
///
/// [TextEditingController] の破棄をダイアログ自身のライフサイクルに閉じるため、
/// 独立した [StatefulWidget] としている。
class WalletDialog extends StatefulWidget {
  const WalletDialog({super.key});

  @override
  State<WalletDialog> createState() => _WalletDialogState();
}

class _WalletDialogState extends State<WalletDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _initialController;
  WalletType _type = WalletType.cash;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _initialController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _initialController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final initial = int.tryParse(_initialController.text.trim().isEmpty
            ? '0'
            : _initialController.text.trim());
    if (name.isEmpty || initial == null || initial < 0) {
      setState(() => _error = '財布名と初期残高を正しく入力してください');
      return;
    }
    Navigator.of(context).pop(
      _WalletDraft(name: name, type: _type, initialBalance: initial),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('財布を追加'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: WalletAppKeys.nameField,
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(labelText: '財布名'),
          ),
          TextField(
            key: WalletAppKeys.initialField,
            controller: _initialController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '初期残高（円）'),
          ),
          DropdownButtonFormField<WalletType>(
            key: WalletAppKeys.typeDropdown,
            initialValue: _type,
            decoration: const InputDecoration(labelText: '種別'),
            items: [
              for (final type in WalletType.values)
                DropdownMenuItem(value: type, child: Text(type.label)),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _type = value);
            },
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                key: WalletAppKeys.dialogError,
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
          key: WalletAppKeys.dialogSaveButton,
          onPressed: _submit,
          child: const Text('保存'),
        ),
      ],
    );
  }
}
