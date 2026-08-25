import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/careerCoach/data/careerCoach_book_bonus_service.dart';
import 'package:kozuchi/features/careerCoach/domain/career_coach_review_service.dart';
import 'package:kozuchi/features/careerCoach/presentation/screens/career_coach_screen.dart';

/// ローディングを見せず即時に結果を返すフェイク講評サービス
class _FakeCareerCoachReviewService implements CareerCoachReviewService {
  final CareerCoachReview review;

  _FakeCareerCoachReviewService(this.review);

  @override
  Future<CareerCoachReview> generateReview(CareerCoachReviewData data) async {
    return review;
  }
}

Widget _buildApp(CareerCoachReviewService service, CareerCoachReviewData data) {
  return MaterialApp(
    home: CareerCoachScreen(reviewData: data, reviewService: service),
  );
}

void main() {
  const surplusData = CareerCoachReviewData(
    weeklyExpenditure: 30000,
    weeklyIncome: 50000,
    monthlyExpenditure: 120000,
  );

  const deficitData = CareerCoachReviewData(
    weeklyExpenditure: 60000,
    weeklyIncome: 50000,
    monthlyExpenditure: 120000,
  );

  testWidgets('shows AppBar title キャリアコーチ', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        _FakeCareerCoachReviewService(
          const CareerCoachReview(
            reviewText: '講評',
            expMultiplier: 1.2,
            isSaving: true,
            balance: 20000,
          ),
        ),
        surplusData,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('キャリアコーチ'), findsOneWidget);
    expect(find.text('弁財天アドバイザー'), findsOneWidget);
  });

  testWidgets('shows review text and balance after loading', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        _FakeCareerCoachReviewService(
          const CareerCoachReview(
            reviewText: 'よく守ったわ。来週も励みなさい。',
            expMultiplier: 1.2,
            isSaving: true,
            balance: 20000,
          ),
        ),
        surplusData,
      ),
    );

    // ロード前はスピナー
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('よく守ったわ。来週も励みなさい。'), findsOneWidget);
    expect(find.textContaining('+¥20,000'), findsOneWidget);
    expect(find.textContaining('黒字'), findsWidgets);
  });

  testWidgets('shows deficit indication for a deficit', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        _FakeCareerCoachReviewService(
          const CareerCoachReview(
            reviewText: '赤字だぞ。費えを見直せ。',
            expMultiplier: 0.8,
            isSaving: false,
            balance: -10000,
          ),
        ),
        deficitData,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('赤字だぞ。費えを見直せ。'), findsOneWidget);
    expect(find.textContaining('赤字'), findsWidgets);
  });

  testWidgets('shows book bonus title when present', (tester) async {
    const data = CareerCoachReviewData(
      weeklyExpenditure: 30000,
      weeklyIncome: 50000,
      monthlyExpenditure: 120000,
      bookBonus: CareerCoachBonusResult(
        bookTitle: '読書論',
        bonusExp: 10,
      ),
    );

    await tester.pumpWidget(
      _buildApp(
        _FakeCareerCoachReviewService(
          const CareerCoachReview(
            reviewText: '蔵書も増えたな。',
            expMultiplier: 1.2,
            isSaving: true,
            balance: 20000,
            bookTitle: '読書論',
          ),
        ),
        data,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('読書論'), findsOneWidget);
    expect(find.text('📚'), findsOneWidget);
  });
}
