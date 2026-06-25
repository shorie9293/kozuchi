import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/effects/domain/guardian_farewell_messages.dart';
import 'package:kozuchi/domain/models/advisor.dart';

void main() {
  group('GuardianFarewellMessages', () {
    test('各アドバイザーの別れの言葉が空でない', () {
      for (final advisor in Advisor.values) {
        final msg = GuardianFarewellMessages.farewell(advisor);
        expect(msg, isNotEmpty);
        expect(msg.length, greaterThan(5));
      }
    });

    test('各アドバイザーの契約メッセージが空でない', () {
      for (final advisor in Advisor.values) {
        final msg = GuardianFarewellMessages.contractGreeting(advisor);
        expect(msg, isNotEmpty);
        expect(msg, contains(advisor.label));
      }
    });

    test('全アドバイザーの別れの言葉が一意である', () {
      final messages = Advisor.values
          .map((a) => GuardianFarewellMessages.farewell(a))
          .toSet();
      expect(messages.length, Advisor.values.length);
    });

    test('全アドバイザーの契約メッセージが一意である', () {
      final messages = Advisor.values
          .map((a) => GuardianFarewellMessages.contractGreeting(a))
          .toSet();
      expect(messages.length, Advisor.values.length);
    });
  });
}
