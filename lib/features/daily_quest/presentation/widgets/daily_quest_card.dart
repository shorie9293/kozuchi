import 'package:flutter/material.dart';
import 'package:kozuchi/domain/models/daily_quest.dart';

/// デイリークエスト1件を表示するカード
///
/// 進捗バー、タイプ別アイコン、EXP/SATORI情報、達成状態を表示する。
/// タップ可能だが、現状では単なる表示用（将来の詳細画面用に拡張可）。
class DailyQuestCard extends StatelessWidget {
  /// 表示するクエスト
  final DailyQuest quest;

  /// カードタップ時のコールバック（任意）
  final VoidCallback? onTap;

  const DailyQuestCard({
    super.key,
    required this.quest,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDone = quest.isCompleted;
    final isFailed = quest.isFailed;
    final progress = quest.progressRatio;

    return Card(
      key: Key('dailyQuestCard_${quest.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isDone
            ? BorderSide(
                color: Colors.green.shade300, width: 1.5)
            : isFailed
                ? BorderSide(
                    color: Colors.red.shade300, width: 1.5)
                : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ヘッダー行：アイコン + タイトル + 状態バッジ
              _buildHeader(colorScheme, isDone, isFailed),
              const SizedBox(height: 8),
              // 説明文
              if (quest.description.isNotEmpty) ...[
                Text(
                  quest.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
              ],
              // 条件ヒント（達成条件がひと目でわかる）
              if (!isDone && !isFailed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.tertiaryContainer.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _conditionHint,
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.tertiary,
                      height: 1.2,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              // 進捗バー（二値型クエスト以外）
              if (!_isBinaryQuest) _buildProgressBar(colorScheme, progress),
              const SizedBox(height: 6),
              // フッター：進捗数値 + EXP/SATORI
              _buildFooter(colorScheme, progress),
            ],
          ),
        ),
      ),
    );
  }

  /// 二値型クエスト（目標値0または1で、進捗表示が不要なもの）
  bool get _isBinaryQuest =>
      quest.targetValue == 0 || quest.targetValue == 1;

  /// タイプ別の条件説明テキスト
  String get _conditionHint {
    switch (quest.type) {
      case DailyQuestType.spendOnSelf:
        return '自己投資カテゴリ（書籍・趣味・美容・教育費など）の支出で進捗';
      case DailyQuestType.receiptScan:
        return '支出時にレシートを撮影すると進捗';
      case DailyQuestType.newCategory:
        return '最近使っていないカテゴリで支出すると達成';
      case DailyQuestType.underBudget:
        return '支出合計が予算以内なら達成、超過で失敗';
      case DailyQuestType.noSpending:
        return '支出が発生したら失敗';
    }
  }

  /// ヘッダー行
  Widget _buildHeader(
      ColorScheme colorScheme, bool isDone, bool isFailed) {
    return Row(
      children: [
        // タイプアイコン
        _buildTypeIcon(),
        const SizedBox(width: 8),
        // タイトル
        Expanded(
          child: Text(
            quest.title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDone
                  ? colorScheme.onSurface.withValues(alpha: 0.6)
                  : isFailed
                      ? Colors.red.shade400
                      : colorScheme.onSurface,
              decoration: isDone
                  ? TextDecoration.lineThrough
                  : null,
            ),
          ),
        ),
        // 状態バッジ
        if (isDone)
          _buildStatusBadge('達成', Colors.green)
        else if (isFailed)
          _buildStatusBadge('失敗', Colors.red),
      ],
    );
  }

  /// クエストタイプに応じたアイコン
  Widget _buildTypeIcon() {
    final (icon, color) = switch (quest.type) {
      DailyQuestType.spendOnSelf => (Icons.favorite, Colors.pink),
      DailyQuestType.receiptScan => (Icons.receipt_long, Colors.teal),
      DailyQuestType.newCategory => (Icons.explore, Colors.purple),
      DailyQuestType.underBudget => (Icons.savings, Colors.blue),
      DailyQuestType.noSpending => (Icons.lock, Colors.orange),
    };

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }

  /// 状態バッジ
  Widget _buildStatusBadge(String label, MaterialColor baseColor) {
    final color = baseColor.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
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

  /// 進捗バー
  Widget _buildProgressBar(ColorScheme colorScheme, double progress) {
    final isDone = quest.isCompleted;
    final barColor = isDone
        ? Colors.green
        : quest.isFailed
            ? Colors.red.shade300
            : _progressColor(progress);

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor:
                colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }

  /// 進捗に応じた色を返す
  Color _progressColor(double progress) {
    if (progress >= 1.0) return Colors.green;
    if (progress >= 0.6) return Colors.lightGreen;
    if (progress >= 0.3) return Colors.amber;
    return Colors.blueGrey.shade300;
  }

  /// フッター行
  Widget _buildFooter(ColorScheme colorScheme, double progress) {
    return Row(
      children: [
        // 進捗テキスト
        if (!_isBinaryQuest)
          Text(
            '${quest.currentProgress} / ${quest.targetValue}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurfaceVariant,
            ),
          )
        else
          Text(
            quest.isCompleted ? '完了' : quest.isFailed ? '失敗' : '未達成',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: quest.isCompleted
                  ? Colors.green.shade600
                  : quest.isFailed
                      ? Colors.red.shade400
                      : colorScheme.onSurfaceVariant,
            ),
          ),
        const Spacer(),
        // EXP獲得 / SATORIペナルティ
        if (quest.isCompleted)
          _buildStatChip(
            'EXP +${quest.expReward}',
            Colors.amber.shade700,
            Icons.star,
          )
        else if (quest.isFailed)
          _buildStatChip(
            'SATORI -${quest.satoriPenalty}',
            Colors.red.shade400,
            Icons.warning_amber_rounded,
          )
        else ...[
          _buildStatChip(
            'EXP +${quest.expReward}',
            Colors.amber.withValues(alpha: 0.6),
            Icons.star_outline,
          ),
          const SizedBox(width: 6),
          _buildStatChip(
            '-${quest.satoriPenalty}',
            Colors.red.withValues(alpha: 0.5),
            Icons.warning_amber_rounded,
          ),
        ],
      ],
    );
  }

  /// EXP/SATORI表示チップ
  Widget _buildStatChip(String label, Color color, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
