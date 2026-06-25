import 'package:flutter/material.dart';
import 'package:kozuchi/domain/models/daily_quest.dart';
import 'package:kozuchi/features/daily_quest/presentation/widgets/daily_quest_card.dart';

/// デイリークエスト一覧ウィジェット
///
/// 本日のデイリークエストを最大3件表示する。
/// 達成済み・進行中・失敗の各状態に対応し、
/// 全達成時には達成エフェクトを表示可能。
class DailyQuestList extends StatelessWidget {
  /// 表示するクエスト一覧
  final List<DailyQuest> quests;

  /// 全クエスト達成時に表示するエフェクト（任意）
  final Widget? allCompletedEffect;

  /// 読み込み中か
  final bool isLoading;

  /// エラーメッセージ
  final String? errorMessage;

  /// 再読み込みコールバック
  final VoidCallback? onRetry;

  /// カードタップ時のコールバック
  final void Function(DailyQuest quest)? onQuestTap;

  const DailyQuestList({
    super.key,
    required this.quests,
    this.allCompletedEffect,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
    this.onQuestTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (isLoading) {
      return const Center(
        key: Key('dailyQuestList_loading'),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (errorMessage != null) {
      return _buildErrorView(colorScheme);
    }

    if (quests.isEmpty) {
      return _buildEmptyView(colorScheme);
    }

    // 達成済み → 進行中 → 失敗 の順にソート
    final sorted = List<DailyQuest>.from(quests)
      ..sort((a, b) {
        if (a.isCompleted && !b.isCompleted) return -1;
        if (!a.isCompleted && b.isCompleted) return 1;
        if (a.isFailed && !b.isFailed) return 1;
        if (!a.isFailed && b.isFailed) return -1;
        return 0;
      });

    final allDone = quests.isNotEmpty && quests.every((q) => q.isCompleted);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // セクションタイトル
        _buildSectionTitle(colorScheme, quests.length, allDone),
        const SizedBox(height: 8),
        // クエストカード一覧
        ...sorted.map((quest) => DailyQuestCard(
              quest: quest,
              onTap: () => onQuestTap?.call(quest),
            )),
        // 全達成エフェクト
        if (allDone && allCompletedEffect != null) ...[
          const SizedBox(height: 8),
          allCompletedEffect!,
        ],
      ],
    );
  }

  /// セクションタイトル
  Widget _buildSectionTitle(
      ColorScheme colorScheme, int count, bool allDone) {
    return Row(
      children: [
        const Text('📋', style: TextStyle(fontSize: 16)),
        const SizedBox(width: 6),
        Text(
          '今日のクエスト',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: allDone
                ? Colors.green.withValues(alpha: 0.15)
                : colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            allDone ? '$count/$count 達成！' : '$count件',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: allDone
                  ? Colors.green.shade700
                  : colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ],
    );
  }

  /// エラー表示
  Widget _buildErrorView(ColorScheme colorScheme) {
    return Container(
      key: const Key('dailyQuestList_error'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 28, color: colorScheme.error),
          const SizedBox(height: 8),
          Text(
            'クエストの読み込みに失敗しました',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 4),
            Text(
              errorMessage!,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('再読み込み'),
            ),
          ],
        ],
      ),
    );
  }

  /// 空表示
  Widget _buildEmptyView(ColorScheme colorScheme) {
    return Container(
      key: const Key('dailyQuestList_empty'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome,
              size: 24, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            '今日のクエストはまだありません',
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
