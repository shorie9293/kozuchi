import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/tutorial/domain/kozuchi_tutorial_step.dart';

void main() {
  group('KozuchiTutorialStep', () {
    test('should have 5 steps', () {
      expect(KozuchiTutorialStep.values.length, equals(5));
      expect(
        KozuchiTutorialStep.values,
        containsAllInOrder([
          KozuchiTutorialStep.welcome,
          KozuchiTutorialStep.advisor,
          KozuchiTutorialStep.offering,
          KozuchiTutorialStep.exp,
          KozuchiTutorialStep.complete,
        ]),
      );
    });

    group('labels', () {
      test('welcome should have correct label', () {
        expect(
          KozuchiTutorialStep.welcome.label,
          equals('打ち出の小槌へようこそ'),
        );
      });

      test('advisor should have correct label', () {
        expect(
          KozuchiTutorialStep.advisor.label,
          equals('アドバイザーとの契約'),
        );
      });

      test('offering should have correct label', () {
        expect(
          KozuchiTutorialStep.offering.label,
          equals('支出の理'),
        );
      });

      test('exp should have correct label', () {
        expect(
          KozuchiTutorialStep.exp.label,
          equals('悟りへの道'),
        );
      });

      test('complete should have correct label', () {
        expect(
          KozuchiTutorialStep.complete.label,
          equals('旅立ち'),
        );
      });
    });

    group('descriptions', () {
      for (final step in KozuchiTutorialStep.values) {
        test('${step.name} should have a non-empty description', () {
          expect(step.description, isNotEmpty);
        });
      }
    });

    group('next progression chain', () {
      test('welcome.next should be advisor', () {
        expect(
          KozuchiTutorialStep.welcome.next,
          equals(KozuchiTutorialStep.advisor),
        );
      });

      test('advisor.next should be offering', () {
        expect(
          KozuchiTutorialStep.advisor.next,
          equals(KozuchiTutorialStep.offering),
        );
      });

      test('offering.next should be exp', () {
        expect(
          KozuchiTutorialStep.offering.next,
          equals(KozuchiTutorialStep.exp),
        );
      });

      test('exp.next should be complete', () {
        expect(
          KozuchiTutorialStep.exp.next,
          equals(KozuchiTutorialStep.complete),
        );
      });

      test('complete.next should be null', () {
        expect(KozuchiTutorialStep.complete.next, isNull);
      });

      test('full progression chain from welcome to null', () {
        expect(
          KozuchiTutorialStep.welcome.next?.next?.next?.next,
          equals(KozuchiTutorialStep.complete),
        );
        expect(
          KozuchiTutorialStep.welcome.next?.next?.next?.next?.next,
          isNull,
        );
      });
    });
  });
}
