import 'package:flutter/material.dart';
import 'package:kozuchi/core/infrastructure/cloud_sync_service.dart';
import 'package:kozuchi/core/infrastructure/supabase_provider.dart';
import 'package:kozuchi/domain/models/monthly_budget.dart';
import 'package:kozuchi/domain/services/expense_aggregation_service.dart';
import 'package:kozuchi/domain/services/supabase_expense_repository.dart';
import 'package:kozuchi/features/budget/data/category_budget_repository.dart';
import 'package:kozuchi/features/budget/domain/category_budget_aggregator.dart';
import 'package:kozuchi/features/budget/domain/category_budget_service.dart';
import 'package:kozuchi/features/budget/domain/category_budget_status.dart';
import 'package:kozuchi/features/budget/presentation/category_budget_app_keys.dart';

/// カテゴリ別予算の設定・超過警告画面
///
/// 月間予算設定画面（[BudgetSettingsScreen]）のAppBarから開く。
/// カテゴリごとの予算上限を設定し、当月支出との比較で
/// 超過・警告（予算の80%以上）・予算内を表示する。
class CategoryBudgetScreen extends StatefulWidget {
  /// カテゴリ別予算の永続化リポジトリ
  final CategoryBudgetRepository repository;

  /// カテゴリ別当月支出を取得するローダ（nullなら既定実装＝Supabaseから取得）
  final Future<Map<String, int>> Function(String yearMonth)? spentLoader;

  /// 表示対象のカテゴリ一覧（nullなら既定カテゴリ）
  final List<String>? categories;

  /// 対象月（YYYY-MM、nullなら現在月）
  final String? yearMonth;

  /// 現在日時（試練で固定日時を注入できるように）
  final DateTime Function()? clock;

  const CategoryBudgetScreen({
    super.key,
    this.repository = const CategoryBudgetRepository(),
    this.spentLoader,
    this.categories,
    this.yearMonth,
    this.clock,
  });

  @override
  State<CategoryBudgetScreen> createState() => _CategoryBudgetScreenState();
}

class _CategoryBudgetScreenState extends State<CategoryBudgetScreen> {
  late String _yearMonth;
  late List<String> _categories;
  Map<String, int> _budgets = const {};
  Map<String, int> _spent = const {};
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _yearMonth = widget.yearMonth ?? MonthlyBudget.currentYearMonth();
    _categories =
        widget.categories ?? ExpenseAggregationService.defaultCategories;
    _reload();
  }

  /// 予算と支出を再読込する
  Future<void> _reload() async {
    try {
      final budgets = await widget.repository.loadBudgets(_yearMonth);
      final loader = widget.spentLoader ?? _defaultSpentLoader;
      final spent = await loader(_yearMonth);
      if (!mounted) return;
      setState(() {
        _budgets = budgets;
        _spent = spent;
        _isLoading = false;
        _hasError = false;
      });
    } catch (_) {
      // 例外を握りつぶし、空マップ扱いで一覧を表示する
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  /// 既定の支出ローダ（Supabaseから当月の支出一覧を取得して集計）
  Future<Map<String, int>> _defaultSpentLoader(String yearMonth) async {
    final parts = yearMonth.split('-');
    final year = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
    final month = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 1;
    final start = DateTime(year, month);
    final end = DateTime(year, month + 1, 0, 23, 59, 59);
    final entries = await SupabaseExpenseRepository(
      cloudStore: CloudSyncService(client: SupabaseProvider.client),
      userIdProvider: () => SupabaseProvider.currentUserId,
    ).getEntries(start: start, end: end);
    return const CategoryBudgetAggregator().spentByCategory(entries);
  }

  /// 全カテゴリの状態を並び順込みで算出する
  ///
  /// 並び順: 超過 → 警告 → 予算内。同状態内は支出額の降順。
  List<CategoryBudgetStatus> _statuses() {
    final statuses = const CategoryBudgetService().evaluate(
      categoryBudgets: _budgets,
      categorySpent: _spent,
    );
    final order = {
      CategoryBudgetState.exceeded: 0,
      CategoryBudgetState.warning: 1,
      CategoryBudgetState.ok: 2,
    };
    return statuses.toList()
      ..sort((a, b) {
        final stateOrder =
            order[a.state]!.compareTo(order[b.state]!);
        if (stateOrder != 0) return stateOrder;
        return b.spent.compareTo(a.spent);
      });
  }

  Future<void> _openEditDialog(String category) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _CategoryBudgetEditDialog(
        category: category,
        initialAmount: _budgets[category] ?? 0,
        repository: widget.repository,
        yearMonth: _yearMonth,
        onSaved: _reload,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statuses = _isLoading ? const <CategoryBudgetStatus>[] : _statuses();
    final warningCount =
        statuses.where((s) => s.state == CategoryBudgetState.warning).length;
    final exceededCount =
        statuses.where((s) => s.state == CategoryBudgetState.exceeded).length;

    // 予算設定済みカテゴリ（サービスの判定対象）
    final evaluated = {
      for (final s in statuses) s.category: s,
    };
    // 未設定カテゴリ（予算未設定・判定対象外）を末尾に並べる
    final unsetRows = _categories
        .where((c) => !evaluated.containsKey(c))
        .map(
          (c) => _RowData(
            category: c,
            budget: 0,
            spent: _spent[c] ?? 0,
            state: null,
          ),
        )
        .toList()
      ..sort((a, b) => b.spent.compareTo(a.spent));

    final rows = <_RowData>[
      for (final s in statuses)
        _RowData(
          category: s.category,
          budget: s.budget,
          spent: s.spent,
          state: s.state,
        ),
      ...unsetRows,
    ];

    return Scaffold(
      key: CategoryBudgetAppKeys.categoryBudgetScreen,
      appBar: AppBar(
        title: const Text('カテゴリ別予算'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SummaryCard(
                  warningCount: warningCount,
                  exceededCount: exceededCount,
                  colorScheme: colorScheme,
                ),
                if (_hasError) ...[
                  const SizedBox(height: 8),
                  Text(
                    '支出データの読み込みに失敗しました',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                for (final row in rows)
                  _CategoryBudgetRow(
                    key: CategoryBudgetAppKeys.row(row.category),
                    data: row,
                    colorScheme: colorScheme,
                    onTap: () => _openEditDialog(row.category),
                  ),
              ],
            ),
    );
  }
}

/// 一覧1行分のデータ（未設定カテゴリは state=null で扱う内部モデル）
class _RowData {
  final String category;
  final int budget;
  final int spent;

  /// null は「予算未設定」を表す
  final CategoryBudgetState? state;

  const _RowData({
    required this.category,
    required this.budget,
    required this.spent,
    required this.state,
  });
}

/// 警告・超過件数のサマリーカード
class _SummaryCard extends StatelessWidget {
  final int warningCount;
  final int exceededCount;
  final ColorScheme colorScheme;

  const _SummaryCard({
    required this.warningCount,
    required this.exceededCount,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: CategoryBudgetAppKeys.categoryBudget_summary,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '警告 $warningCount件 ・ 超過 $exceededCount件',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface,
        ),
      ),
    );
  }
}

/// カテゴリ1行分の表示
class _CategoryBudgetRow extends StatelessWidget {
  final _RowData data;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  const _CategoryBudgetRow({
    super.key,
    required this.data,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isExceeded = data.state == CategoryBudgetState.exceeded;
    final isWarning = data.state == CategoryBudgetState.warning;
    final progressColor = isExceeded
        ? colorScheme.error
        : isWarning
            ? Colors.amber
            : colorScheme.primary;

    final stateLabel = switch (data.state) {
      CategoryBudgetState.exceeded => '超過',
      CategoryBudgetState.warning => 'まもなく超過',
      CategoryBudgetState.ok => '予算内',
      null => '未設定',
    };

    final amountText = data.budget > 0 ? '¥${data.spent} / ¥${data.budget}' : '未設定';
    final remainingText = isExceeded ? '¥${data.spent - data.budget} 超過' : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      data.category,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    stateLabel,
                    key: CategoryBudgetAppKeys.state(data.category),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isExceeded
                          ? colorScheme.error
                          : isWarning
                              ? Colors.amber.shade700
                              : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      amountText,
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (remainingText != null)
                    Text(
                      remainingText,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              if (data.budget > 0) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (data.spent / data.budget).clamp(0.0, 1.0),
                  color: progressColor,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// カテゴリ別予算の編集ダイアログ
///
/// TextEditingController をこの State のライフサイクル内で dispose する
/// （呼出側で即 dispose すると 'used after being disposed' になるため）。
class _CategoryBudgetEditDialog extends StatefulWidget {
  final String category;
  final int initialAmount;
  final CategoryBudgetRepository repository;
  final String yearMonth;
  final Future<void> Function() onSaved;

  const _CategoryBudgetEditDialog({
    required this.category,
    required this.initialAmount,
    required this.repository,
    required this.yearMonth,
    required this.onSaved,
  });

  @override
  State<_CategoryBudgetEditDialog> createState() =>
      _CategoryBudgetEditDialogState();
}

class _CategoryBudgetEditDialogState extends State<_CategoryBudgetEditDialog> {
  late final TextEditingController _amountController;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.initialAmount > 0 ? widget.initialAmount.toString() : '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  /// 保存ボタン処理
  ///
  /// - 非数値・負数: エラー表示のみ（保存しない）
  /// - 0: 未設定扱い（removeBudget と同じ）
  /// - 正数: saveBudget
  Future<void> _save() async {
    final text = _amountController.text.trim();
    final amount = int.tryParse(text);
    if (amount == null || amount < 0) {
      setState(() => _errorText = '有効な金額を入力してください');
      return;
    }

    final navigator = Navigator.of(context);
    if (amount == 0) {
      await widget.repository.removeBudget(widget.yearMonth, widget.category);
    } else {
      await widget.repository.saveBudget(
        widget.yearMonth,
        widget.category,
        amount,
      );
    }
    await widget.onSaved();
    navigator.pop();
  }

  /// 解除ボタン処理（未設定に戻す）
  Future<void> _remove() async {
    final navigator = Navigator.of(context);
    await widget.repository.removeBudget(widget.yearMonth, widget.category);
    await widget.onSaved();
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: CategoryBudgetAppKeys.categoryBudget_editDialog,
      title: Text(widget.category),
      content: TextField(
        key: CategoryBudgetAppKeys.categoryBudget_amountField,
        controller: _amountController,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: '予算額（円）',
          hintText: '例: 30000',
          prefixText: '¥ ',
          errorText: _errorText,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        if (widget.initialAmount > 0)
          TextButton(
            key: CategoryBudgetAppKeys.categoryBudget_removeButton,
            onPressed: _remove,
            child: const Text('解除'),
          ),
        TextButton(
          key: CategoryBudgetAppKeys.categoryBudget_saveButton,
          onPressed: _save,
          child: const Text('保存'),
        ),
      ],
    );
  }
}