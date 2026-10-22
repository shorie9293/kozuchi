import 'package:flutter/material.dart';

import 'package:kozuchi/features/weekly_quest/domain/models/active_weekly_quest.dart';
import 'package:kozuchi/features/weekly_quest/domain/weekly_quest_progress.dart';
import 'package:kozuchi/features/weekly_quest/presentation/weekly_quest_app_keys.dart';

/// 週次クエスト1件のカード。
///
/// [WeeklyQuestProgress] が表示文字列をすべて持つため、ここでは並べるだけ。
/// 達成（completed）は緑、失敗（failed）は赤で塗り分ける。
class WeeklyQuestCard extends StatelessWidget {
  /// 表示する進捗スナップショット。
  final WeeklyQuestProgress progress;

  /// タップ時の処理（null なら非インタラクティブ）。
  final VoidCallback? onTap;

  /// 余白を詰めたコンパクト表示にするか。
  final bool compact;

  const WeeklyQuestCard({
    super.key,
    required this.progress,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = _accentColor(colorScheme);
    final padding = compact ? 12.0 : 16.0;

    final content = Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _chip(
                label: progress.quest.difficulty.label,
                color: colorScheme.secondary,
                colorScheme: colorScheme,
              ),
              const SizedBox(width: 8),
              _chip(
                key: WeeklyQuestAppKeys.statusChip(progress.quest.id),
                label: progress.statusLabel,
                color: accent,
                colorScheme: colorScheme,
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            progress.quest.title,
            style: TextStyle(
              fontSize: compact ? 14 : 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.ratio,
              minHeight: 6,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                progress.spentLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                progress.summaryLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return KeyedSubtree(
      key: WeeklyQuestAppKeys.card(progress.quest.id),
      child: Card(
        margin: EdgeInsets.only(bottom: compact ? 8 : 12),
        color: accent.withValues(alpha: 0.06),
        child: onTap == null
            ? content
            : InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: content,
              ),
      ),
    );
  }

  /// 状態に応じたアクセント色。
  Color _accentColor(ColorScheme colorScheme) {
    switch (progress.status) {
      case WeeklyQuestStatus.completed:
        return const Color(0xFF2E7D32);
      case WeeklyQuestStatus.failed:
        return colorScheme.error;
      case WeeklyQuestStatus.active:
        return colorScheme.primary;
      case WeeklyQuestStatus.pending:
        return colorScheme.outline;
    }
  }

  Widget _chip({
    Key? key,
    required String label,
    required Color color,
    required ColorScheme colorScheme,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
