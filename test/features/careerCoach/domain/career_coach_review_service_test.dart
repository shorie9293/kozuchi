import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/advisor.dart';
import 'package:kozuchi/features/careerCoach/data/careerCoach_book_bonus_service.dart';
import 'package:kozuchi/features/careerCoach/domain/career_coach_review_service.dart';
import 'package:kozuchi/features/trial_quest/domain/ai_review_service.dart';

/// 講評AIを模倣するフェイクサービス
class _FakeAiReviewService implements AiReviewService {
  final AiReviewResult result;
  final Object? error;

  _FakeAiReviewService({AiReviewResult? result, this.error})
      : result =
            result ?? const AiReviewResult(reviewText: 'AI講評', expMultiplier: 1.5);

  @override
  Future<AiReviewResult> generateReview({
    required Advisor deity,
    required String reflection,
    required int offeringAmount,
    required String offeringPurpose,
  }) async {
    if (error != null) throw error!;
    return result;
  }
}

void main() {
  group('CareerCoachReviewData', () {
    test('computes balance and isSaving for a surplus', () {
      const data = CareerCoachReviewData(
        weeklyExpenditure: 30000,
        weeklyIncome: 50000,
        monthlyExpenditure: 120000,
      );

      expect(data.balance, 20000);
      expect(data.isSaving, isTrue);
      expect(data.savingRatio, 0.4);
    });

    test('computes balance and isSaving for a deficit', () {
      const data = CareerCoachReviewData(
        weeklyExpenditure: 60000,
        weeklyIncome: 50000,
        monthlyExpenditure: 120000,
      );

      expect(data.balance, -10000);
      expect(data.isSaving, isFalse);
      expect(data.savingRatio, 0.0);
    });

    test('defaults guardian to benzaiten', () {
      const data = CareerCoachReviewData(
        weeklyExpenditure: 10000,
        weeklyIncome: 10000,
        monthlyExpenditure: 40000,
      );
      expect(data.guardian, Advisor.benzaiten);
    });
  });

  group('AiCareerCoachReviewService', () {
    test('buildReflection includes weekly figures and book title', () {
      const data = CareerCoachReviewData(
        weeklyExpenditure: 30000,
        weeklyIncome: 50000,
        monthlyExpenditure: 120000,
        bookBonus: CareerCoachBonusResult(
          bookTitle: '読書論',
          bookAuthor: '某著者',
          bonusExp: 10,
        ),
      );

      final service = AiCareerCoachReviewService(_FakeAiReviewService());
      final reflection = service.buildReflection(data);

      expect(reflection, contains('30000'));
      expect(reflection, contains('50000'));
      expect(reflection, contains('読書論'));
      expect(reflection, contains('黒字'));
    });

    test('generateReview delegates to AiReviewService and maps result', () async {
      const data = CareerCoachReviewData(
        weeklyExpenditure: 30000,
        weeklyIncome: 50000,
        monthlyExpenditure: 120000,
      );

      final service = AiCareerCoachReviewService(
        _FakeAiReviewService(
          result: const AiReviewResult(reviewText: 'よく守った', expMultiplier: 1.5),
        ),
      );

      final review = await service.generateReview(data);

      expect(review.reviewText, 'よく守った');
      expect(review.expMultiplier, 1.5);
      expect(review.isSaving, isTrue);
      expect(review.balance, 20000);
    });

    test('falls back to local review when AI service throws', () async {
      const data = CareerCoachReviewData(
        weeklyExpenditure: 60000,
        weeklyIncome: 50000,
        monthlyExpenditure: 120000,
      );

      final service = AiCareerCoachReviewService(
        _FakeAiReviewService(error: Exception('network')),
      );

      final review = await service.generateReview(data);

      expect(review.reviewText, contains('赤字'));
      expect(review.expMultiplier, 1.0);
      expect(review.isSaving, isFalse);
    });

    test('maps bookBonus title into the review result', () async {
      const data = CareerCoachReviewData(
        weeklyExpenditure: 30000,
        weeklyIncome: 50000,
        monthlyExpenditure: 120000,
        bookBonus: CareerCoachBonusResult(
          bookTitle: '読書論',
          bonusExp: 10,
        ),
      );

      final service = AiCareerCoachReviewService(_FakeAiReviewService());
      final review = await service.generateReview(data);

      expect(review.bookTitle, '読書論');
    });
  });

  group('MockCareerCoachReviewService', () {
    test('produces a saving review for a surplus', () async {
      const data = CareerCoachReviewData(
        weeklyExpenditure: 30000,
        weeklyIncome: 50000,
        monthlyExpenditure: 120000,
      );

      final review = await MockCareerCoachReviewService().generateReview(data);

      expect(review.reviewText, contains('守'));
      expect(review.expMultiplier, greaterThan(1.0));
      expect(review.isSaving, isTrue);
    });

    test('produces a cautionary review for a deficit', () async {
      const data = CareerCoachReviewData(
        weeklyExpenditure: 60000,
        weeklyIncome: 50000,
        monthlyExpenditure: 120000,
      );

      final review = await MockCareerCoachReviewService().generateReview(data);

      expect(review.reviewText, contains('見直し'));
      expect(review.expMultiplier, lessThan(1.0));
      expect(review.isSaving, isFalse);
    });
  });
}
