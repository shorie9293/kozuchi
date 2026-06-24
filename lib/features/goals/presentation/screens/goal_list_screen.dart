import 'package:flutter/material.dart';
import 'package:kozuchi/features/goals/data/goal.dart';
import 'package:kozuchi/features/goals/data/goal_api_service.dart';
import 'package:kozuchi/features/goals/presentation/screens/goal_form_screen.dart';

/// 目標一覧画面
///
/// 各目標のタイトル・目標金額・期限・進捗バー・ステータスを表示する。
/// 完了した目標は視覚的に区別される。
class GoalListScreen extends StatefulWidget {
  final GoalApiService apiService;

  const GoalListScreen({super.key, required this.apiService});

  @override
  State<GoalListScreen> createState() => _GoalListScreenState();
}

class _GoalListScreenState extends State<GoalListScreen> {
  List<Goal> _goals = [];
  bool _isLoading = true;
  String? _error;
  String? _statusFilter; // null = 全て

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await widget.apiService.listGoals(
        status: _statusFilter,
      );
      if (mounted) {
        setState(() {
          _goals = response.goals;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteGoal(Goal goal) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('目標を削除'),
        content: Text('「${goal.title}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await widget.apiService.deleteGoal(goal.id);
      _loadGoals();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除に失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _navigateToForm({Goal? existingGoal}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => GoalFormScreen(
          apiService: widget.apiService,
          existingGoal: existingGoal,
        ),
      ),
    );

    if (result == true) {
      _loadGoals();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('貯蓄目標'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'ステータスフィルタ',
            onSelected: (value) {
              setState(() {
                _statusFilter = value.isEmpty ? null : value;
              });
              _loadGoals();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: '', child: Text('すべて')),
              const PopupMenuItem(value: 'active', child: Text('進行中')),
              const PopupMenuItem(value: 'completed', child: Text('達成済み')),
              const PopupMenuItem(value: 'cancelled', child: Text('キャンセル')),
            ],
          ),
        ],
      ),
      body: _buildBody(colorScheme),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToForm(),
        icon: const Icon(Icons.add),
        label: const Text('目標を追加'),
      ),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: colorScheme.error)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadGoals,
              child: const Text('再読み込み'),
            ),
          ],
        ),
      );
    }

    if (_goals.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag_outlined, size: 64, color: colorScheme.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              _statusFilter != null ? '該当する目標はありません' : 'まだ目標がありません',
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 8),
            if (_statusFilter == null)
              Text(
                '右下のボタンから目標を追加してください',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadGoals,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _goals.length,
        itemBuilder: (context, index) => _GoalCard(
          goal: _goals[index],
          onTap: () => _navigateToForm(existingGoal: _goals[index]),
          onDelete: () => _deleteGoal(_goals[index]),
        ),
      ),
    );
  }
}

/// 単一の目標カード
class _GoalCard extends StatelessWidget {
  final Goal goal;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _GoalCard({
    required this.goal,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCompleted = goal.isCompleted;
    final isOverdue = goal.isOverdue;

    // ステータスに応じた色
    final statusColor = switch (goal.status) {
      'completed' => Colors.green,
      'cancelled' => Colors.grey,
      _ when isOverdue => Colors.orange,
      _ => colorScheme.primary,
    };

    final statusLabel = switch (goal.status) {
      'completed' => '🎉 達成',
      'cancelled' => 'キャンセル',
      _ when isOverdue => '⚠️ 期限切れ',
      _ => '進行中',
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isCompleted ? 1 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isCompleted
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.transparent,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // タイトル行
              Row(
                children: [
                  Expanded(
                    child: Text(
                      goal.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        decoration:
                            isCompleted ? TextDecoration.lineThrough : null,
                        color: isCompleted
                            ? colorScheme.onSurface.withValues(alpha: 0.5)
                            : null,
                      ),
                    ),
                  ),
                  // ステータスバッジ
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 金額情報
              Row(
                children: [
                  Text(
                    '${goal.formatAmount(goal.currentAmount)} / ${goal.formatAmount(goal.targetAmount)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  if (goal.progressPercent != null)
                    Text(
                      '${goal.progressPercent!.toStringAsFixed(1)}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // 進捗バー
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: goal.progressRatio,
                  minHeight: 8,
                  backgroundColor:
                      colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isCompleted
                        ? Colors.green
                        : isOverdue
                            ? Colors.orange
                            : statusColor,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // 期限 + 削除ボタン
              Row(
                children: [
                  if (goal.deadline != null) ...[
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      goal.deadline!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isOverdue
                            ? Colors.orange
                            : colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Text(
                    '作成: ${_formatDate(goal.createdAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: onDelete,
                    tooltip: '削除',
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(
                      foregroundColor:
                          colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
