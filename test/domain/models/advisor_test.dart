import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/advisor.dart';

void main() {
  group('Advisor', () {
    test('四天のアドバイザーが定義されている', () {
      expect(Advisor.values.length, 4);
      expect(Advisor.values, contains(Advisor.lifePlanner));
      expect(Advisor.values, contains(Advisor.careerCoach));
      expect(Advisor.values, contains(Advisor.investmentMentor));
      expect(Advisor.values, contains(Advisor.wellnessAdvisor));
    });

    test('ライフプランナーは福・食・財を領分とする', () {
      expect(Advisor.lifePlanner.domain, '福・食・財');
      expect(Advisor.lifePlanner.label, 'ライフプランナー');
    });

    test('キャリアコーチは学び・芸術を領分とする', () {
      expect(Advisor.careerCoach.domain, '学び・芸術');
      expect(Advisor.careerCoach.label, 'キャリアコーチ');
    });

    test('投資メンターは戦い・勝負を領分とする', () {
      expect(Advisor.investmentMentor.domain, '戦い・勝負');
      expect(Advisor.investmentMentor.label, '投資メンター');
    });

    test('ウェルネスアドバイザーは美・幸福を領分とする', () {
      expect(Advisor.wellnessAdvisor.domain, '美・幸福');
      expect(Advisor.wellnessAdvisor.label, 'ウェルネスアドバイザー');
    });
  });
}
