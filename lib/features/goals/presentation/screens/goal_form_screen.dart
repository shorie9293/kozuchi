import 'package:flutter/material.dart';
import 'package:kozuchi/features/goals/data/goal.dart';
import 'package:kozuchi/features/goals/data/goal_api_service.dart';

/// 目標作成・編集画面
///
/// 新規作成時は [existingGoal] = null。
/// 編集時は [existingGoal] に既存の目標を渡す。
class GoalFormScreen extends StatefulWidget {
  final GoalApiService apiService;
  final Goal? existingGoal;

  const GoalFormScreen({
    super.key,
    required this.apiService,
    this.existingGoal,
  });

  bool get isEditing => existingGoal != null;

  @override
  State<GoalFormScreen> createState() => _GoalFormScreenState();
}

class _GoalFormScreenState extends State<GoalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _targetAmountController;
  late final TextEditingController _currentAmountController;
  DateTime? _deadline;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final goal = widget.existingGoal;
    _titleController = TextEditingController(text: goal?.title ?? '');
    _targetAmountController = TextEditingController(
      text: goal?.targetAmount.toString() ?? '',
    );
    _currentAmountController = TextEditingController(
      text: goal?.currentAmount.toString() ?? '0',
    );
    if (goal?.deadline != null) {
      _deadline = DateTime.tryParse(goal!.deadline!);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _targetAmountController.dispose();
    _currentAmountController.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
      helpText: '達成期限を選択',
      cancelText: 'キャンセル',
      confirmText: '決定',
    );

    if (picked != null) {
      setState(() => _deadline = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final title = _titleController.text.trim();
      final targetAmount = int.parse(_targetAmountController.text.trim());
      final currentAmount = _currentAmountController.text.trim().isEmpty
          ? 0
          : int.parse(_currentAmountController.text.trim());
      final deadlineStr = _deadline != null
          ? '${_deadline!.year}-${_deadline!.month.toString().padLeft(2, '0')}-${_deadline!.day.toString().padLeft(2, '0')}'
          : null;

      if (widget.isEditing) {
        await widget.apiService.updateGoal(
          widget.existingGoal!.id,
          title: title,
          targetAmount: targetAmount,
          deadline: deadlineStr,
          currentAmount: currentAmount,
        );
      } else {
        await widget.apiService.createGoal(
          title: title,
          targetAmount: targetAmount,
          deadline: deadlineStr,
          currentAmount: currentAmount,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true); // 変更があったことを通知
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEditing = widget.isEditing;
    final goal = widget.existingGoal;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '目標を編集' : '新しい目標'),
        actions: [
          if (isEditing)
            TextButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('保存'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // タイトル
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: '目標タイトル',
                  hintText: '例: 月末までに¥50,000貯める',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.flag),
                ),
                maxLength: 200,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'タイトルを入力してください';
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              // 目標金額
              TextFormField(
                controller: _targetAmountController,
                decoration: const InputDecoration(
                  labelText: '目標金額',
                  hintText: '例: 50000',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.savings),
                  suffixText: '円',
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return '目標金額を入力してください';
                  }
                  final amount = int.tryParse(v.trim());
                  if (amount == null || amount <= 0) {
                    return '正の整数で入力してください';
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              // 現在の積立額
              TextFormField(
                controller: _currentAmountController,
                decoration: InputDecoration(
                  labelText: '現在の積立額',
                  hintText: '例: 15000',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.trending_up),
                  suffixText: '円',
                  helperText: isEditing
                      ? '進捗を更新すると自動で達成判定されます'
                      : '初期積立額があれば入力',
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v != null && v.trim().isNotEmpty) {
                    final amount = int.tryParse(v.trim());
                    if (amount == null || amount < 0) {
                      return '0以上の整数で入力してください';
                    }
                  }
                  return null;
                },
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 16),

              // 期限
              InkWell(
                onTap: _pickDeadline,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '達成期限（任意）',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                    suffixIcon: Icon(Icons.edit_calendar),
                  ),
                  child: Text(
                    _deadline != null
                        ? '${_deadline!.year}年${_deadline!.month}月${_deadline!.day}日'
                        : '設定しない',
                    style: TextStyle(
                      color: _deadline != null
                          ? colorScheme.onSurface
                          : colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              if (_deadline != null) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _deadline = null),
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('期限をクリア'),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // ステータス変更（編集時のみ）
              if (isEditing && goal != null) ...[
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'ステータス変更',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _StatusChip(
                      label: '進行中',
                      selected: goal.status == 'active',
                      color: colorScheme.primary,
                      onTap: goal.status != 'active'
                          ? () async {
                              await widget.apiService.updateGoal(
                                goal.id,
                                status: 'active',
                              );
                              Navigator.of(context).pop(true);
                            }
                          : null,
                    ),
                    _StatusChip(
                      label: '達成済み',
                      selected: goal.status == 'completed',
                      color: Colors.green,
                      onTap: goal.status != 'completed'
                          ? () async {
                              await widget.apiService.updateGoal(
                                goal.id,
                                status: 'completed',
                              );
                              Navigator.of(context).pop(true);
                            }
                          : null,
                    ),
                    _StatusChip(
                      label: 'キャンセル',
                      selected: goal.status == 'cancelled',
                      color: Colors.grey,
                      onTap: goal.status != 'cancelled'
                          ? () async {
                              await widget.apiService.updateGoal(
                                goal.id,
                                status: 'cancelled',
                              );
                              Navigator.of(context).pop(true);
                            }
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // 保存ボタン（新規作成時は下部に大きく表示）
              if (!isEditing) ...[
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.add),
                  label: const Text('目標を作成'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// ステータス選択チップ
class _StatusChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback? onTap;

  const _StatusChip({
    required this.label,
    required this.selected,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: color.withValues(alpha: 0.2),
      onSelected: onTap != null ? (_) => onTap!() : null,
      labelStyle: TextStyle(
        color: selected ? color : null,
        fontWeight: selected ? FontWeight.bold : null,
      ),
    );
  }
}
