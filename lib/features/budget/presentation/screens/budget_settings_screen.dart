import 'package:flutter/material.dart';
import 'package:kozuchi/domain/models/monthly_budget.dart';
import 'package:kozuchi/features/shared/data/budget_repository.dart';

/// 月間予算設定画面
///
/// ユーザーが月の予算額を入力・保存する画面。
/// 現在月の予算が既に設定されている場合は初期表示する。
class BudgetSettingsScreen extends StatefulWidget {
  final BudgetRepository repository;
  final VoidCallback? onSaved;

  const BudgetSettingsScreen({
    super.key,
    required this.repository,
    this.onSaved,
  });

  @override
  State<BudgetSettingsScreen> createState() => _BudgetSettingsScreenState();
}

class _BudgetSettingsScreenState extends State<BudgetSettingsScreen> {
  late final TextEditingController _amountController;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  String _currentMonth = '';

  @override
  void initState() {
    super.initState();
    _currentMonth = MonthlyBudget.currentYearMonth();
    _amountController = TextEditingController();
    _loadExistingBudget();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingBudget() async {
    final existing = await widget.repository.loadBudget(_currentMonth);
    if (existing != null && existing.amount > 0 && mounted) {
      _amountController.text = existing.amount.toString();
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveBudget() async {
    final text = _amountController.text.trim();
    if (text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('予算額を入力してください')),
        );
      }
      return;
    }

    final amount = int.tryParse(text);
    if (amount == null || amount < 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('有効な金額を入力してください')),
        );
      }
      return;
    }

    final budget = MonthlyBudget(yearMonth: _currentMonth, amount: amount);
    await widget.repository.saveBudget(budget);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('予算を設定しました: ¥$amount')),
      );
      widget.onSaved?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('月間予算設定'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 現在の年月表示
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _currentMonth,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // 説明文
                    Text(
                      '今月の予算額を入力してください',
                      style: TextStyle(
                        fontSize: 16,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 予算入力欄
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: '予算額（円）',
                        hintText: '例: 150000',
                        prefixText: '¥ ',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: colorScheme.surface,
                      ),
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(height: 32),

                    // 保存ボタン
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _saveBudget,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          '予算を設定する',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
