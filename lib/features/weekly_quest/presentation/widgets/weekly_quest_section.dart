import 'package:flutter/material.dart';

import 'package:kozuchi/features/weekly_quest/domain/weekly_quest_period.dart';
import 'package:kozuchi/features/weekly_quest/presentation/state/weekly_quest_notifier.dart';
import 'package:kozuchi/features/weekly_quest/presentation/weekly_quest_app_keys.dart';
import 'package:kozuchi/features/weekly_quest/presentation/widgets/weekly_quest_card.dart';

/// ホーム画面に埋め込む週次クエストセクション。
///
/// 表示は [WeeklyQuestNotifier] の状態のみから組み立てる。
/// ウィジェット内で `DateTime.now()` は呼ばない（週ラベルは
/// [periodOverride] か `state.weekKey` から得る）。
class WeeklyQuestSection extends StatelessWidget {
  /// 状態の供給元。
  final WeeklyQuestNotifier notifier;

  /// 選択画面を開く処理。
  final VoidCallback? onOpenSelection;

  /// 失敗時の再試行処理。
  final VoidCallback? onRetry;

  /// 週ラベルの上書き（試練・呼び出し元が週を確定している場合に使う）。
  final WeeklyQuestPeriod? periodOverride;

  const WeeklyQuestSection({
    super.key,
    required this.notifier,
    this.onOpenSelection,
    this.onRetry,
    this.periodOverride,
  });

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: WeeklyQuestAppKeys.section,
      child: ListenableBuilder(
        listenable: notifier,
        builder: (context, _) => _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final weekLabel = periodOverride?.label ?? notifier.state?.weekKey ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '🗓 今週のクエスト',
                key: WeeklyQuestAppKeys.title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            if (weekLabel.isNotEmpty)
              Text(
                weekLabel,
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _buildContent(context, colorScheme),
      ],
    );
  }

  Widget _buildContent(BuildContext context, ColorScheme colorScheme) {
    if (notifier.isLoading) {
      return const Padding(
        key: WeeklyQuestAppKeys.loading,
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final error = notifier.errorMessage;
    if (error != null) {
      return Column(
        key: const Key('weeklyQuestSection_error'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '週次クエストを読み込めませんでした',
            style: TextStyle(fontSize: 13, color: colorScheme.error),
          ),
          const SizedBox(height: 4),
          Text(
            error,
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: WeeklyQuestAppKeys.retryButton,
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('再試行'),
          ),
        ],
      );
    }

    final active = notifier.activeQuest;
    final progress = notifier.activeProgress;
    final pending = notifier.pendingQuests;

    if (active == null && pending.isEmpty) {
      return Container(
        key: WeeklyQuestAppKeys.empty,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          '今週のクエストはまだありません',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (active != null && progress != null)
          KeyedSubtree(
            key: WeeklyQuestAppKeys.activeCard,
            child: WeeklyQuestCard(progress: progress),
          ),
        if (pending.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: FilledButton.tonalIcon(
              key: WeeklyQuestAppKeys.selectButton,
              onPressed: onOpenSelection,
              icon: const Icon(Icons.emoji_events_outlined, size: 18),
              label: Text('今週のクエストを選ぶ（候補 ${pending.length}件）'),
            ),
          ),
      ],
    );
  }
}
