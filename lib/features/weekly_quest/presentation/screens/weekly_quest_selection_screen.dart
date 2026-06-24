import 'package:flutter/material.dart';
import 'package:kozuchi/features/weekly_quest/data/weekly_quest_repository.dart';
import 'package:kozuchi/features/weekly_quest/domain/models/active_weekly_quest.dart';
import 'package:kozuchi/features/weekly_quest/domain/models/weekly_quest.dart';

/// 週間クエスト選択画面
///
/// 毎週月曜に生成された3〜5件のクエスト候補から
/// 1つを選択するUIを提供する。
///
/// 選択後は [onQuestSelected] コールバックが呼ばれ、
/// 呼び出し元で状態更新・永続化を行う。
///
/// [repository] でデータソースを注入可能（テスト時はMock）。
class WeeklyQuestSelectionScreen extends StatefulWidget {
  /// クエストデータのリポジトリ
  final WeeklyQuestRepository repository;

  /// ユーザーID
  final String userId;

  /// クエスト選択時のコールバック
  final void Function(ActiveWeeklyQuest selectedQuest)? onQuestSelected;

  const WeeklyQuestSelectionScreen({
    super.key,
    required this.repository,
    required this.userId,
    this.onQuestSelected,
  });

  @override
  State<WeeklyQuestSelectionScreen> createState() =>
      _WeeklyQuestSelectionScreenState();
}

class _WeeklyQuestSelectionScreenState
    extends State<WeeklyQuestSelectionScreen> {
  List<ActiveWeeklyQuest>? _quests;
  bool _isLoading = true;
  bool _isSelecting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadQuests();
  }

  Future<void> _loadQuests() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final quests =
          await widget.repository.getPendingQuests(widget.userId);
      if (mounted) {
        setState(() {
          _quests = quests;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectQuest(ActiveWeeklyQuest quest) async {
    setState(() => _isSelecting = true);

    try {
      await widget.repository.selectQuest(widget.userId, quest.quest.id);
      if (mounted) {
        final activated = quest.activate();
        widget.onQuestSelected?.call(activated);

        // 選択完了をSnackBarで通知
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('「${quest.quest.title}」を選択しました！'),
              backgroundColor: Colors.green.shade700,
              duration: const Duration(seconds: 2),
            ),
          );
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSelecting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('選択に失敗しました: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      key: const Key('weeklyQuestSelectionScreen'),
      appBar: AppBar(
        title: const Text('📋 今週のクエスト選択'),
        centerTitle: true,
      ),
      body: _buildBody(colorScheme),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    if (_isLoading) {
      return const Center(
        key: Key('weeklyQuestSelection_loadingIndicator'),
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        key: const Key('weeklyQuestSelection_errorView'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: colorScheme.error),
              const SizedBox(height: 16),
              Text(
                'クエストの読み込みに失敗しました',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _loadQuests,
                icon: const Icon(Icons.refresh),
                label: const Text('再読み込み'),
              ),
            ],
          ),
        ),
      );
    }

    final quests = _quests ?? [];

    if (quests.isEmpty) {
      return Center(
        key: const Key('weeklyQuestSelection_emptyView'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline,
                  size: 48, color: colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                '今週のクエストはありません',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '来週の月曜に新しいクエストが生成されます。',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      key: const Key('weeklyQuestSelection_questList'),
      padding: const EdgeInsets.all(16),
      itemCount: quests.length,
      itemBuilder: (context, index) {
        return _buildQuestCard(quests[index], colorScheme);
      },
    );
  }

  Widget _buildQuestCard(ActiveWeeklyQuest activeQuest, ColorScheme colorScheme) {
    final quest = activeQuest.quest;
    final difficultyColor = _difficultyColor(quest.difficulty);
    final reductionPercent = quest.reductionPercent.toInt();

    return Card(
      key: Key('weeklyQuestCard_${quest.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // タイトル行：難易度バッジ + タイトル
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 難易度バッジ
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: difficultyColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: difficultyColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    quest.difficulty.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: difficultyColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // カテゴリタグ
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    quest.targetCategory,
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const Spacer(),
                // 削減率ラベル
                if (reductionPercent > 0)
                  Text(
                    '-$reductionPercent%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: difficultyColor,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // タイトル
            Text(
              quest.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),

            // 説明
            Text(
              quest.description,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),

            // 比較表示：平均 → 予算上限
            Row(
              children: [
                _buildAmountChip(
                  '直近平均',
                  quest.currentAvgSpend,
                  colorScheme.outline,
                  colorScheme,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward, size: 16),
                ),
                _buildAmountChip(
                  '予算上限',
                  quest.budgetLimit,
                  difficultyColor,
                  colorScheme,
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),

            // 選択ボタン
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: Key('weeklyQuest_selectButton_${quest.id}'),
                onPressed:
                    _isSelecting ? null : () => _selectQuest(activeQuest),
                icon: _isSelecting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline, size: 18),
                label: Text(_isSelecting ? '選択中...' : 'このクエストに挑戦する'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: difficultyColor.withValues(alpha: 0.1),
                  foregroundColor: difficultyColor,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 金額表示チップ
  Widget _buildAmountChip(
    String label,
    int amount,
    Color color,
    ColorScheme colorScheme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            '¥${amount.toInt()}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// 難易度に応じた色
  Color _difficultyColor(QuestDifficulty difficulty) {
    switch (difficulty) {
      case QuestDifficulty.easy:
        return Colors.green;
      case QuestDifficulty.medium:
        return Colors.orange;
      case QuestDifficulty.hard:
        return Colors.red;
    }
  }
}
