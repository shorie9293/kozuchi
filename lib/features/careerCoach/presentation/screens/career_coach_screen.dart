import 'package:flutter/material.dart';
import 'package:kozuchi/features/careerCoach/domain/career_coach_review_service.dart';
import 'package:kozuchi/features/trial_quest/data/deepseek_review_service.dart';

/// キャリアコーチ（弁財天アドバイザー）講評画面
///
/// 週次の家計・支出・蔵書ボーナス・守護神状態に基づく講評を表示する。
///
/// [reviewService] が null の場合は既存の AI 講評基盤
/// （[DeepSeekReviewService]）を利用したサービスで講評を生成する。
/// テストでは [MockCareerCoachReviewService] などを注入できる。
class CareerCoachScreen extends StatefulWidget {
  final CareerCoachReviewData reviewData;
  final CareerCoachReviewService? reviewService;

  const CareerCoachScreen({
    super.key,
    required this.reviewData,
    this.reviewService,
  });

  @override
  State<CareerCoachScreen> createState() => _CareerCoachScreenState();
}

class _CareerCoachScreenState extends State<CareerCoachScreen> {
  CareerCoachReview? _review;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReview();
  }

  Future<void> _loadReview() async {
    final service = widget.reviewService ??
        AiCareerCoachReviewService(DeepSeekReviewService());
    final review = await service.generateReview(widget.reviewData);
    if (mounted) {
      setState(() {
        _review = review;
        _isLoading = false;
      });
    }
  }

  /// 収支額を表示用フォーマットに変換（例: +¥20,000 / -¥10,000）
  String _formatBalance(int balance) {
    final sign = balance >= 0 ? '+' : '-';
    final s = balance.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '$sign¥$buf';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      key: const Key('career_coach_screen'),
      appBar: AppBar(title: const Text('キャリアコーチ')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAdvisorHeader(colorScheme),
                  const SizedBox(height: 16),
                  _buildBalanceCard(colorScheme),
                  if (_review!.bookTitle != null) ...[
                    const SizedBox(height: 16),
                    _buildBookBonusCard(colorScheme),
                  ],
                  const SizedBox(height: 16),
                  _buildReviewCard(colorScheme),
                ],
              ),
            ),
    );
  }

  Widget _buildAdvisorHeader(ColorScheme colorScheme) {
    final guardian = widget.reviewData.guardian;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(guardian.emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '弁財天アドバイザー',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${guardian.label}が今週の家計を吟味する',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(ColorScheme colorScheme) {
    final review = _review!;
    final isSaving = review.isSaving;
    final statusColor = isSaving ? Colors.green : colorScheme.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '今週の収支',
            style: TextStyle(fontSize: 12, color: colorScheme.outline),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                _formatBalance(review.balance),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isSaving ? '黒字' : '赤字',
                  style: TextStyle(fontSize: 12, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'EXP倍率: x${review.expMultiplier.toStringAsFixed(1)}',
            style: TextStyle(fontSize: 12, color: colorScheme.outline),
          ),
        ],
      ),
    );
  }

  Widget _buildBookBonusCard(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Text('📚', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '蔵書ボーナス:「${_review!.bookTitle}」を読みました',
              style: TextStyle(fontSize: 13, color: colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.tertiary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📜 キャリアコーチ講評',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Text(
            _review!.reviewText,
            style: TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: colorScheme.onTertiaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
