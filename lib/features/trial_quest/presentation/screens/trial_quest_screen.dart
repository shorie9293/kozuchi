import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kozuchi/domain/models/trial_quest.dart';
import 'package:kozuchi/domain/models/player_model.dart';
import 'package:kozuchi/domain/classifier/classifier_service.dart';
import 'package:kozuchi/features/trial_quest/presentation/screens/offering_input_screen.dart';
import 'package:kozuchi/features/trial_quest/presentation/screens/reflection_screen.dart';
import 'package:kozuchi/features/trial_quest/domain/ai_review_service.dart';
import 'package:kozuchi/domain/models/exp_calculation.dart';
import 'package:kozuchi/features/effects/presentation/effect_manager.dart';

/// 試練クエスト画面
///
/// 試練受注 → 支出入力 → 振り返り → アドバイザー講評 の基本ループを実装する。
///
/// [aiReviewService] が null の場合はモック講評を使用する。
class TrialQuestScreen extends StatefulWidget {
  final TrialQuest quest;
  final PlayerModel player;
  final void Function(TrialQuest quest, PlayerModel player) onQuestUpdated;
  final AiReviewService? aiReviewService;

  /// 支出記録時に呼ばれるコールバック（デイリークエスト進捗検出用）
  ///
  /// [amount] 支出金額（円）
  /// [category] 支出用途（カテゴリ）
  final void Function(int amount, String category)? onExpenseRecorded;

  const TrialQuestScreen({
    super.key,
    required this.quest,
    required this.player,
    required this.onQuestUpdated,
    this.aiReviewService,
    this.onExpenseRecorded,
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
      // デイリークエスト進捗検出用のコールバック
      widget.onExpenseRecorded?.call(result.amount, result.purpose);

      // 分類器で自動タグ付け
      final classification =
          ClassifierService.instance.classify(result.purpose);
      final updatedQuest = _quest.recordOffering(
        amount: result.amount,
        purpose: result.purpose,
        note: result.note,
        classifiedCategory:
            result.category ?? classification.category,
      );
      _updateQuest(updatedQuest, result.updatedPlayer);
      // 支出実行エフェクト：画面中央にコイン散布
      EffectManager.of(context).playEffect(
        'coin_scatter',
        Offset(
          MediaQuery.of(context).size.width / 2,
          MediaQuery.of(context).size.height / 2,
        ),
      );
      // 画面フラッシュ演出（爽快感向上）
      EffectManager.of(context).playEffect('offering_flash', Offset.zero);
      // 触覚フィードバック
      HapticFeedback.mediumImpact();
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
            deity: updatedQuest.advisor,
            reflection: result,
            offeringAmount: updatedQuest.offeringAmount ?? 0,
            offeringPurpose: updatedQuest.offeringPurpose ?? '',
          );
          updatedQuest = updatedQuest.withReview(aiResult.reviewText);
          final expGain = _calculateExpGain(
            updatedQuest,
            aiResult.expMultiplier,
          );
          _updateQuest(updatedQuest, _player.addExp(expGain));
        } else {
          updatedQuest = updatedQuest.withReview(
            _generateMockReview(updatedQuest),
          );
          final expGain = _calculateExpGain(updatedQuest);
          _updateQuest(updatedQuest, _player.addExp(expGain));
        }
      } catch (_) {
        updatedQuest = updatedQuest.withReview(
          _generateMockReview(updatedQuest),
        );
        final expGain = _calculateExpGain(updatedQuest);
        _updateQuest(updatedQuest, _player.addExp(expGain));
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

  int _calculateExpGain(TrialQuest quest, [double multiplier = 1.0]) {
    if (quest.offeringAmount == null) return 0;
    final advisorMultiplier = _player.advisor?.expMultiplier ?? 1.0;
    return calculateQuestExpGain(
      offeringAmount: quest.offeringAmount!,
      aiMultiplier: multiplier,
      advisorMultiplier: advisorMultiplier,
    );
  }

  String _generateMockReview(TrialQuest quest) {
    final deity = quest.advisor;
    final reflection = quest.reflection ?? '';
    final hasInsight = reflection.length > 20;

    if (hasInsight) {
      return '${deity.label}「うむ、その内省の中に確かな悟りの灯を見た。'
          '支出の痛みは執着の手放しに他ならぬ。よく励んだ。」';
    }
    return '${deity.label}「支出の行は善きかな。されど振り返りが浅い。'
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
                  // アドバイザー表示
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
                          _quest.advisor.emoji,
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _quest.advisor.label,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 完了条件セクション
                  _buildCompletionConditions(colorScheme),
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
                  // 支出目安
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          '💰 支出目安: ',
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
                        label: const Text('支出を記録する'),
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
                color: Colors.black54,
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
            '✅ 支出記録済み',
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
                '📜 アドバイザー講評',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              Text(
                'ゴール達成への一歩',
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

  /// 完了条件セクションを構築する
  Widget _buildCompletionConditions(ColorScheme colorScheme) {
    final isOfferingDone = _quest.isOfferingRecorded;
    final isReflectionDone = _quest.isReflectionRecorded;
    final completedSteps = (isOfferingDone ? 1 : 0) + (isReflectionDone ? 1 : 0);
    final totalSteps = 2;
    final allDone = _quest.isCompleted;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: allDone
            ? Colors.green.withValues(alpha: 0.1)
            : colorScheme.primaryContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: allDone
              ? Colors.green.withValues(alpha: 0.4)
              : colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー：タイトル＋進捗
          Row(
            children: [
              Icon(
                allDone ? Icons.check_circle : Icons.flag_outlined,
                size: 18,
                color: allDone ? Colors.green : colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                allDone ? '✓ クエスト完了' : '完了条件',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: allDone ? Colors.green.shade700 : colorScheme.primary,
                ),
              ),
              const Spacer(),
              // 進捗表示: Step 1/2 形式
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: allDone
                      ? Colors.green.withValues(alpha: 0.15)
                      : colorScheme.surface.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  allDone ? '✓ $totalSteps/$totalSteps' : '$completedSteps/$totalSteps',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: allDone ? Colors.green.shade700 : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Step1: 支出を記録する
          _buildStepRow(
            stepNumber: 1,
            label: '支出を記録する',
            isDone: isOfferingDone,
            colorScheme: colorScheme,
          ),
          const SizedBox(height: 4),
          // Step2: 振り返りを書く
          _buildStepRow(
            stepNumber: 2,
            label: '振り返りを書く',
            isDone: isReflectionDone,
            colorScheme: colorScheme,
          ),
        ],
      ),
    );
  }

  /// 個別ステップ行
  Widget _buildStepRow({
    required int stepNumber,
    required String label,
    required bool isDone,
    required ColorScheme colorScheme,
  }) {
    return Row(
      children: [
        Icon(
          isDone ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 16,
          color: isDone ? Colors.green : colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Text(
          'Step $stepNumber: ',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDone
                ? Colors.green.shade600
                : colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDone
                ? Colors.green.shade600
                : colorScheme.onSurface,
            decoration: isDone ? TextDecoration.lineThrough : null,
          ),
        ),
        if (isDone) ...[
          const SizedBox(width: 4),
          const Icon(Icons.check, size: 12, color: Colors.green),
        ],
      ],
    );
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }
}
