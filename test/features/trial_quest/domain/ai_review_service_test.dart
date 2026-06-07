import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/trial_quest/domain/ai_review_service.dart';

void main() {
  group('AiReviewResult', () {
    test('コンストラクタで全フィールドが正しく設定される', () {
      const reviewText = '素晴らしい行いです。その慈悲の心を忘れずに。';
      const satoriMultiplier = 1.5;

      final result = AiReviewResult(
        reviewText: reviewText,
        satoriMultiplier: satoriMultiplier,
      );

      expect(result.reviewText, reviewText);
      expect(result.satoriMultiplier, satoriMultiplier);
    });
  });
}
