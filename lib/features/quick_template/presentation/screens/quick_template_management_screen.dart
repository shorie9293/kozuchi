import 'package:flutter/material.dart';

import 'package:kozuchi/features/quick_template/data/quick_template_repository.dart';
import 'package:kozuchi/features/quick_template/domain/models/expense_template.dart';
import 'package:kozuchi/features/quick_template/domain/quick_template_service.dart';
import 'package:kozuchi/features/quick_template/presentation/quick_template_app_keys.dart';

/// クイックテンプレート管理画面
///
/// テンプレートの一覧（使用回数・金額・カテゴリ表示）、追加ダイアログ、
/// 削除を提供する。使用回数順に表示する。
/// [repository] を注入できる（試練ではメモリ内実装を使う）。
class QuickTemplateManagementScreen extends StatefulWidget {
  /// テンプレートの永続化先（未指定時は SharedPreferences 実装）
  final QuickTemplateRepository? repository;

  const QuickTemplateManagementScreen({super.key, this.repository});

  @override
  State<QuickTemplateManagementScreen> createState() =>
      _QuickTemplateManagementScreenState();
}

class _QuickTemplateManagementScreenState
    extends State<QuickTemplateManagementScreen> {
  late final QuickTemplateRepository _repository;
  List<ExpenseTemplate> _templates = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? const SharedPreferencesQuickTemplateRepository();
    _reload();
  }

  /// テンプレート一覧を再読込する。
  Future<void> _reload() async {
    final templates = await _repository.loadTemplates();
    if (!mounted) return;
    setState(() {
      _templates = QuickTemplateService.sortByUsage(templates);
      _loading = false;
    });
  }

  /// 追加ダイアログを開く。
  Future<void> _showAddDialog() async {
    final result = await showDialog<_TemplateFormResult>(
      context: context,
      builder: (_) => const _TemplateAddDialog(),
    );
    if (result == null) return;

    final template = ExpenseTemplate(
      id: 'tpl_${DateTime.now().microsecondsSinceEpoch}',
      amount: result.amount,
      purpose: result.purpose,
      category: result.category,
      useCount: 0,
      createdAt: DateTime.now(),
    );
    final updated = QuickTemplateService.upsert(_templates, template);
    await _repository.saveTemplates(updated);
    await _reload();
  }

  /// 指定テンプレートを削除する。
  Future<void> _delete(String id) async {
    final updated = QuickTemplateService.remove(_templates, id);
    await _repository.saveTemplates(updated);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      key: QuickTemplateAppKeys.managementScreen,
      appBar: AppBar(
        title: const Text('テンプレート管理'),
        actions: [
          IconButton(
            key: QuickTemplateAppKeys.addButton,
            icon: const Icon(Icons.add),
            tooltip: 'テンプレートを追加',
            onPressed: _showAddDialog,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _templates.isEmpty
              ? Center(
                  child: Text(
                    'テンプレートはまだありません',
                    style: TextStyle(color: colorScheme.outline),
                  ),
                )
              : ListView(
                  children: [
                    for (final template in _templates)
                      ListTile(
                        key: QuickTemplateAppKeys.listTile(template.id),
                        title: Text(template.purpose),
                        subtitle: Text(
                          '¥${template.amount}・${template.category}'
                          '・使用 ${template.useCount}回',
                        ),
                        trailing: IconButton(
                          key: QuickTemplateAppKeys.deleteButton(template.id),
                          icon: const Icon(Icons.delete_outline),
                          tooltip: '削除',
                          onPressed: () => _delete(template.id),
                        ),
                      ),
                  ],
                ),
    );
  }
}

/// 追加ダイアログの結果。
class _TemplateFormResult {
  final int amount;
  final String purpose;
  final String category;

  const _TemplateFormResult({
    required this.amount,
    required this.purpose,
    required this.category,
  });
}

/// テンプレート追加ダイアログ（金額・用途・カテゴリ）。
class _TemplateAddDialog extends StatefulWidget {
  const _TemplateAddDialog();

  @override
  State<_TemplateAddDialog> createState() => _TemplateAddDialogState();
}

class _TemplateAddDialogState extends State<_TemplateAddDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _purposeController = TextEditingController();
  String? _selectedCategory;

  static const List<String> _categories = [
    '食費', '娯楽', '交通', '光熱費', '交際費', 'その他',
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) return;
    Navigator.of(context).pop(_TemplateFormResult(
      amount: int.parse(_amountController.text),
      purpose: _purposeController.text.trim(),
      category: _selectedCategory!,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('テンプレートを追加'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: QuickTemplateAppKeys.amountField,
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '金額（円）',
                prefixText: '¥ ',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final amount = int.tryParse(value ?? '');
                if (amount == null || amount <= 0) return '有効な金額を入力せよ';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: QuickTemplateAppKeys.purposeField,
              controller: _purposeController,
              decoration: const InputDecoration(
                labelText: '用途',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return '用途を入力せよ';
                return null;
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final category in _categories)
                  ChoiceChip(
                    label: Text(category, style: const TextStyle(fontSize: 12)),
                    selected: _selectedCategory == category,
                    onSelected: (selected) =>
                        setState(() => _selectedCategory = selected ? category : null),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          key: QuickTemplateAppKeys.saveButton,
          onPressed: _selectedCategory == null ? null : _submit,
          child: const Text('保存'),
        ),
      ],
    );
  }
}
