import 'package:flutter/material.dart';
import 'package:kozuchi/domain/models/trial_quest.dart';
import 'package:kozuchi/domain/models/player_model.dart';
import 'package:kozuchi/features/trial_quest/presentation/screens/offering_input_screen.dart';
import 'package:kozuchi/features/trial_quest/presentation/screens/reflection_screen.dart';
import 'package:kozuchi/features/trial_quest/domain/ai_review_service.dart';

/// 試練クエスト画面
///
/// 試練受注 → 喜捨入力 → 振り返り → 守護神講評 の基本ループを実装する。
///
/// [aiReviewService] が null の場合はモック講評を使用する。
class TrialQuestScreen extends StatefulWidget {
  final TrialQuest quest;
  final PlayerModel player;
  final void Function(TrialQuest quest, PlayerModel player) onQuestUpdated;
  final AiReviewService? aiReviewService;

  const TrialQuestScreen({
    super.key,
    required this.quest,
    required this.player,
    required this.onQuestUpdated,
    this.aiReviewService,
  });

  @override
  State<TrialQuestScreen> createState() => _TrialQuestScreenState();
}

class _TrialQuestScreenState extends State<TrialQuestScreen> {
  late TrialQuest _quest;
  late PlayerModel _player;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _quest = widget.quest;
    _player = widget.player;
  }

  void _updateQuest(TrialQuest quest, PlayerModel player) {
    setState(() {
      _quest = quest;
      _player = player;
    });
    widget.onQuestUpdated(quest, player);
  }

  Future<void> _openOfferingInput() async {
    final result = await Navigator.of(context).push<OfferingResult>(
      MaterialPageRoute(
        builder: (_) => OfferingInputScreen(
          quest: _quest,
          player: _player,
        ),
      ),
    );
    if (result != null) {
      final updatedQuest = _quest.recordOffering(
        amount: result.amount,
        purpose: result.purpose,
        note: result.note,
      );
      _updateQuest(updatedQuest, result.updatedPlayer);
    }
  }

  Future<void> _openReflection() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ReflectionScreen(quest: _quest),
      ),
    );
    if (result != null && result.isNotEmpty) {
      _showLoadingIndicator();
      var updatedQuest = _quest.recordReflection(result);
      try {
        final aiReviewService = widget.aiReviewService;
        if (aiReviewService != null) {
          final aiResult = await aiReviewService.generateReview(
            deity: updatedQuest.guardianDeity,
            reflection: result,
            offeringAmount: updatedQuest.offeringAmount ?? 0,
            offeringPurpose: updatedQuest.offeringPurpose ?? '',
          );
          updatedQuest = updatedQuest.withReview(aiResult.reviewText);
          final satoriGain = _calculateSatoriGain(
            updatedQuest,
            aiResult.satoriMultiplier,
          );
          _updateQuest(updatedQuest, _player.addSatori(satoriGain));
        } else {
          updatedQuest = updatedQuest.withReview(
            _generateMockReview(updatedQuest),
          );
          final satoriGain = _calculateSatoriGain(updatedQuest);
          _updateQuest(updatedQuest, _player.addSatori(satoriGain));
        }
      } catch (_) {
        updatedQuest = updatedQuest.withReview(
          _generateMockReview(updatedQuest),
        );
        final satoriGain = _calculateSatoriGain(updatedQuest);
        _updateQuest(updatedQuest, _player.addSatori(satoriGain));
      } finally {
        _hideLoadingIndicator();
      }
    }
  }

  void _showLoadingIndicator() {
    setState(() => _isLoading = true);
  }

  void _hideLoadingIndicator() {
    if (mounted) setState(() => _isLoading = false);
  }

  int _calculateSatoriGain(TrialQuest quest, [double multiplier = 1.0]) {
    if (quest.offeringAmount == null) return 0;
    final base = 5 + (quest.offeringAmount! / 1000).floor();
    return (base * multiplier).round();
  }

  String _generateMockReview(TrialQuest quest) {
    final deity = quest.guardianDeity;
    final reflection = quest.reflection ?? '';
    final hasInsight = reflection.length > 20;

    if (hasInsight) {
      return '${deity.label}「うむ、その内省の中に確かな悟りの灯を見た。'
          '喜捨の痛みは執着の手放しに他ならぬ。よく励んだ。」';
    }
    return '${deity.label}「喜捨の行は善きかな。されど振り返りが浅い。'
        'もう一度、その金が巡った先に想いを馳せよ。」';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return KeyedSubtree(
      key: const Key('trial_quest_screen'),
      child: Scaffold(
        appBar: AppBar(
          title: Text(_quest.title),
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 守護神表示
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _quest.guardianDeity.emoji,
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _quest.guardianDeity.label,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 説明
                  Text(
                    _quest.description,
                    style: TextStyle(
                      fontSize: 16,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 喜捨目安
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          '💰 喜捨目安: ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '¥${_formatNumber(_quest.suggestedOffering)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 状態表示とアクション
                  if (!_quest.isOfferingRecorded) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _openOfferingInput,
                        icon: const Icon(Icons.paid),
                        label: const Text('喜捨を記録する'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ] else if (_quest.isOfferingRecorded &&
                      !_quest.isReflectionRecorded) ...[
                    _buildRecordedOfferingInfo(colorScheme),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _openReflection,
                        icon: const Icon(Icons.edit_note),
                        label: const Text('振り返りを書く'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ] else if (_quest.isCompleted) ...[
                    _buildRecordedOfferingInfo(colorScheme),
                    const SizedBox(height: 16),
                    _buildReviewSection(colorScheme),
                  ],
                ],
              ),
            ),
            if (_isLoading)
              Container(
                color: Colors.black26,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordedOfferingInfo(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '✅ 喜捨記録済み',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: colorScheme.secondary,
            ),
          ),
          const SizedBox(height: 4),
          if (_quest.offeringAmount != null)
            Text('金額: ¥${_formatNumber(_quest.offeringAmount!)}'),
          if (_quest.offeringPurpose != null)
            Text('用途: ${_quest.offeringPurpose}'),
          if (_quest.offeringNote != null && _quest.offeringNote!.isNotEmpty)
            Text('メモ: ${_quest.offeringNote}'),
        ],
      ),
    );
  }

  Widget _buildReviewSection(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.tertiary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '📜 守護神講評',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              Text(
                '解脱への一歩',
                style: TextStyle(fontSize: 12, color: colorScheme.outline),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_quest.reflection != null) ...[
            Text(
              'あなたの振り返り:',
              style: TextStyle(fontSize: 12, color: colorScheme.outline),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_quest.reflection!),
            ),
            const SizedBox(height: 12),
          ],
          if (_quest.review != null) ...[
            const Divider(),
            Text(
              _quest.review!,
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: colorScheme.onTertiaryContainer,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }
}
