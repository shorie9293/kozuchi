import 'package:flutter/material.dart';
import 'package:kozuchi/domain/models/monthly_budget.dart';
import 'package:kozuchi/features/budget/data/rollover_settings_repository.dart';
import 'package:kozuchi/features/budget/domain/budget_rollover.dart';
import 'package:kozuchi/features/budget/domain/budget_rollover_service.dart';
import 'package:kozuchi/features/shared/data/budget_repository.dart';

/// 月間予算設定画面
///
/// ユーザーが月の予算額を入力・保存する画面。
/// 現在月の予算が既に設定されている場合は初期表示する。
/// 前月の残額を翌月へ繰り越す「予算繰り越し」の設定・プレビューも行う。
class BudgetSettingsScreen extends StatefulWidget {
  final BudgetRepository repository;
  final VoidCallback? onSaved;

  /// 繰り越し設定の永続化リポジトリ
  final RolloverSettingsRepository rolloverRepository;

  const BudgetSettingsScreen({
    super.key,
    required this.repository,
    this.onSaved,
    this.rolloverRepository = const RolloverSettingsRepository(),
  });

  @override
  State<BudgetSettingsScreen> createState() => _BudgetSettingsScreenState();
}

class _BudgetSettingsScreenState extends State<BudgetSettingsScreen> {
  late final TextEditingController _amountController;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  String _currentMonth = '';

  /// 繰り越し設定（デフォルト＝無効）
  RolloverSettings _rolloverSettings = RolloverSettings.defaults;

  /// 前月実績から算出した繰り越しプレビュー
  BudgetRollover _rollover = const BudgetRollover(baseBudget: 0);

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
    await _refreshRollover();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  /// 前月の予算・支出一実績と繰り越し設定からプレビューを再計算する
  Future<void> _refreshRollover() async {
    final settings = await widget.rolloverRepository.load();
    final prevMonth = MonthlyBudget.previousYearMonth(from: _currentMonth);
    final prevBudget = await widget.repository.loadBudget(prevMonth);
    final prevSpent = await widget.repository.loadMonthlySpending(prevMonth);
    final baseAmount = int.tryParse(_amountController.text.trim()) ?? 0;

    final rollover = BudgetRolloverService(carryOverCap: settings.cap).compute(
      baseBudget: baseAmount,
      previousBudget: prevBudget?.amount ?? 0,
      previousSpent: prevSpent,
      enabled: settings.enabled,
    );

    if (mounted) {
      setState(() {
        _rolloverSettings = settings;
        _rollover = rollover;
      });
    }
  }

  /// 繰り越しの有効/無効を切り替えて保存・再計算する
  Future<void> _toggleRollover(bool enabled) async {
    await widget.rolloverRepository.setEnabled(enabled);
    await _refreshRollover();
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
    await _refreshRollover();

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

                    // 予算繰り越しカード
                    _buildRolloverCard(colorScheme),
                    const SizedBox(height: 24),

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
                      onChanged: (_) => _refreshRollover(),
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

  /// 予算繰り越しのプレビューカード＋有効化スイッチ
  Widget _buildRolloverCard(ColorScheme colorScheme) {
    final rollover = _rollover;
    final children = <Widget>[
      Row(
        children: [
          Icon(Icons.savings_outlined, color: colorScheme.primary, size: 22),
          const SizedBox(width: 8),
          Text(
            '予算の繰り越し',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Row(
        children: [
          Expanded(
            child: Text(
              _rolloverSettings.enabled ? '先月の残りを今月に繰り越す' : '繰り越しを使わない',
              style: TextStyle(fontSize: 13, color: colorScheme.onSurface),
            ),
          ),
          Switch(
            value: _rolloverSettings.enabled,
            onChanged: _toggleRollover,
          ),
        ],
      ),
    ];

    if (rollover.hasOverspend) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          '先月の超過: ¥${rollover.overspend} — 今月は使いすぎに注意',
          style: TextStyle(
            fontSize: 13,
            color: colorScheme.error,
            fontWeight: FontWeight.w600,
          ),
        ),
      ));
    }

    if (rollover.hasCarryOver) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          '先月からの繰越: ¥${rollover.carryOver} → 実質予算 ¥${rollover.effectiveBudget}',
          style: TextStyle(
            fontSize: 13,
            color: colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ));
    }

    if (rollover.isNeutral) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          '先月の繰越・超過はありません',
          style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
        ),
      ));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
