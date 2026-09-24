import 'package:flutter/material.dart';

import 'package:kozuchi/core/infrastructure/cloud_sync_service.dart';
import 'package:kozuchi/core/infrastructure/supabase_provider.dart';
import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/domain/services/supabase_expense_repository.dart';
import 'package:kozuchi/features/category_ledger/data/category_ledger_repository.dart';
import 'package:kozuchi/features/category_ledger/domain/category_ledger.dart';
import 'package:kozuchi/features/category_ledger/domain/category_ledger_service.dart';
import 'package:kozuchi/features/category_ledger/domain/category_usage.dart';
import 'package:kozuchi/features/category_ledger/presentation/category_ledger_app_keys.dart';

/// カテゴリ管理画面
///
/// ユーザー定義カテゴリの一覧・追加・改名・削除・リセットを行う。
/// 台帳は [CategoryLedgerRepository] 経由で永続化する。
class CategoryLedgerScreen extends StatefulWidget {
  /// 台帳の永続化先（省略時は SharedPreferences 実装）
  final CategoryLedgerRepository repository;

  /// 使用実績の算出に使う支出データ（試練用の直接注入）
  final List<ExpenseEntry>? entries;

  /// 本番用の支出ローダ（Supabase から当月分を取得する）
  final Future<List<ExpenseEntry>> Function()? entriesLoader;

  const CategoryLedgerScreen({
    super.key,
    this.repository = const SharedPreferencesCategoryLedgerRepository(),
    this.entries,
    this.entriesLoader,
  });

  @override
  State<CategoryLedgerScreen> createState() => _CategoryLedgerScreenState();
}

class _CategoryLedgerScreenState extends State<CategoryLedgerScreen> {
  static const CategoryLedgerService _service = CategoryLedgerService();

  CategoryLedger _ledger = CategoryLedger.defaults();
  List<CategoryUsage> _usages = const [];
  List<ExpenseEntry> _currentEntries = const [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  /// 台帳と支出使用実績を再読込する
  Future<void> _reload() async {
    try {
      final ledger = await widget.repository.loadLedger();
      final entries = await _loadEntries();
      if (!mounted) return;
      setState(() {
        _ledger = ledger;
        _currentEntries = entries;
        _usages = _service.usage(ledger, entries);
        _isLoading = false;
        _hasError = false;
      });
    } catch (_) {
      // 例外を画面に漏らさない
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  /// 使用実績のもとになる支出一覧を取得する
  Future<List<ExpenseEntry>> _loadEntries() async {
    if (widget.entries != null) return widget.entries!;
    if (widget.entriesLoader != null) return widget.entriesLoader!();
    return _defaultEntriesLoader();
  }

  /// 既定の支出ローダ（Supabase から当月分を取得）
  Future<List<ExpenseEntry>> _defaultEntriesLoader() async {
    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month);
      final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      return await SupabaseExpenseRepository(
        cloudStore: CloudSyncService(client: SupabaseProvider.client),
        userIdProvider: () => SupabaseProvider.currentUserId,
      ).getEntries(start: start, end: end);
    } catch (_) {
      // 未ログイン・初期化前などは実績なしとして扱う
      return const <ExpenseEntry>[];
    }
  }

  CategoryUsage _usageOf(String category) {
    for (final usage in _usages) {
      if (usage.category == category) return usage;
    }
    return CategoryUsage(
      category: category,
      count: 0,
      amount: 0,
      inLedger: true,
    );
  }

  /// 追加・改名ダイアログを開く。[target] が null なら追加モード。
  Future<void> _openEditDialog({String? target}) async {
    final isNew = target == null;
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _CategoryNameDialog(
        title: isNew ? 'カテゴリを追加' : 'カテゴリ名を変更',
        initialName: isNew ? '' : target,
        onValidate: (raw) {
          if (isNew) return _service.validateNew(_ledger, raw);
          final newName = CategoryLedgerService.normalize(raw);
          if (newName.isEmpty) return CategoryNameError.empty;
          if (newName.length > CategoryLedgerService.maxNameLength) {
            return CategoryNameError.tooLong;
          }
          if (newName == CategoryLedgerService.normalize(target)) return null;
          final clash = _ledger.categories.any(
            (c) =>
                CategoryLedgerService.normalize(c) == newName &&
                CategoryLedgerService.normalize(c) !=
                    CategoryLedgerService.normalize(target),
          );
          return clash ? CategoryNameError.duplicate : null;
        },
      ),
    );
    final raw = result;
    if (raw == null || raw.isEmpty) return;

    try {
      final next = isNew
          ? _service.add(_ledger, raw)
          : _service.rename(_ledger, target, raw);
      await widget.repository.saveLedger(next);
      if (!mounted) return;
      await _reload();
    } on ArgumentError {
      // 保存直前の競合。例外は画面に漏らさない
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('カテゴリを保存できませんでした')),
      );
    }
  }

  /// 削除確認ダイアログ
  Future<void> _confirmRemove(String category) async {
    final usage = _usageOf(category);
    final inUse = _service.isInUse(category, _currentEntries);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        key: CategoryLedgerAppKeys.categoryLedger_dialog,
        title: const Text('カテゴリを削除'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('「$category」を削除しますか？'),
            if (inUse)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${usage.count}件の取引で使用されています',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            key: CategoryLedgerAppKeys.deleteButton(category),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    if (_ledger.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('最後のカテゴリは削除できません')),
      );
      return;
    }
    try {
      final next = _service.remove(_ledger, category);
      await widget.repository.saveLedger(next);
      if (!mounted) return;
      await _reload();
    } on ArgumentError {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('カテゴリを削除できませんでした')),
      );
    }
  }

  /// リセット確認ダイアログ
  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('カテゴリをリセット'),
        content: const Text('すべてのカテゴリを既定の状態に戻します。よろしいですか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('リセット'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final next = _service.reset();
    await widget.repository.saveLedger(next);
    if (!mounted) return;
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      key: CategoryLedgerAppKeys.categoryLedgerScreen,
      appBar: AppBar(
        title: const Text('カテゴリ管理'),
        centerTitle: true,
        actions: [
          IconButton(
            key: CategoryLedgerAppKeys.categoryLedger_resetButton,
            icon: const Icon(Icons.restore),
            tooltip: 'リセット',
            onPressed: _isLoading ? null : _confirmReset,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: CategoryLedgerAppKeys.categoryLedger_addButton,
        onPressed: _isLoading ? null : () => _openEditDialog(),
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? Center(
                  child: Text(
                    'データの読み込みに失敗しました',
                    style: TextStyle(color: colorScheme.error),
                  ),
                )
              : _buildList(),
    );
  }

  Widget _buildList() {
    // 台帳順 + 台帳に無い孤立カテゴリ
    final rows = [
      for (final category in _ledger.categories) _usageOf(category),
      ..._usages.where((u) => !u.inLedger),
    ];
    if (rows.isEmpty) {
      return const Center(
        child: Text(
          'カテゴリがありません',
          key: CategoryLedgerAppKeys.categoryLedger_emptyText,
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final usage = rows[index];
        return _CategoryRow(
          key: CategoryLedgerAppKeys.row(usage.category),
          usage: usage,
          menuKey: CategoryLedgerAppKeys.menuButton(usage.category),
          onRename: () => _openEditDialog(target: usage.category),
          onDelete: () => _confirmRemove(usage.category),
        );
      },
    );
  }
}

/// 台帳1行分の表示（絵文字＋カテゴリ名＋使用実績＋メニュー）
class _CategoryRow extends StatelessWidget {
  final CategoryUsage usage;
  final Key menuKey;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _CategoryRow({
    super.key,
    required this.usage,
    required this.menuKey,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final emoji = const CategoryLedgerService().emojiFor(usage.category);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          usage.category,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (!usage.inLedger) ...[
                        const SizedBox(width: 6),
                        Text(
                          '台帳に無いカテゴリ',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    '使用 ${usage.count}件 / ¥${usage.amount}',
                    key: CategoryLedgerAppKeys.usage(usage.category),
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              key: menuKey,
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'rename') onRename();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rename', child: Text('名前を変更')),
                PopupMenuItem(value: 'delete', child: Text('削除')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 追加・改名共通の名前入力ダイアログ
class _CategoryNameDialog extends StatefulWidget {
  final String title;
  final String initialName;
  final CategoryNameError? Function(String raw) onValidate;

  const _CategoryNameDialog({
    required this.title,
    required this.initialName,
    required this.onValidate,
  });

  @override
  State<_CategoryNameDialog> createState() => _CategoryNameDialogState();
}

class _CategoryNameDialogState extends State<_CategoryNameDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final raw = CategoryLedgerService.normalize(_controller.text);
    final error = widget.onValidate(raw);
    if (error != null) {
      setState(() => _errorText = _messageFor(error));
      return;
    }
    Navigator.of(context).pop(raw);
  }

  String _messageFor(CategoryNameError error) {
    switch (error) {
      case CategoryNameError.empty:
        return 'カテゴリ名を入力してください';
      case CategoryNameError.tooLong:
        return 'カテゴリ名は${CategoryLedgerService.maxNameLength}文字以内にしてください';
      case CategoryNameError.duplicate:
        return 'そのカテゴリ名は既に存在します';
      case CategoryNameError.notFound:
        return 'カテゴリが台帳に存在しません';
      case CategoryNameError.lastOne:
        return '最後のカテゴリは削除できません';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: CategoryLedgerAppKeys.categoryLedger_dialog,
      title: Text(widget.title),
      content: TextField(
        key: CategoryLedgerAppKeys.categoryLedger_nameField,
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'カテゴリ名',
          errorText: _errorText,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('キャンセル'),
        ),
        TextButton(
          key: CategoryLedgerAppKeys.categoryLedger_saveButton,
          onPressed: _save,
          child: const Text('保存'),
        ),
      ],
    );
  }
}