import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/trial_quest.dart';
import 'package:kozuchi/domain/models/guardian_deity.dart';

void main() {
  group('TrialQuest', () {
    test('週間試練を生成できる', () {
      final quest = TrialQuest(
        title: '誰かと食事を共にせよ',
        description: '友人や家族と食事をし、会計を済ませよ',
        suggestedOffering: 3000,
        guardianDeity: GuardianDeity.daikokuten,
      );
      expect(quest.title, '誰かと食事を共にせよ');
      expect(quest.suggestedOffering, 3000);
      expect(quest.guardianDeity, GuardianDeity.daikokuten);
      expect(quest.isCompleted, isFalse);
    });

    test('喜捨を記録できる', () {
      final quest = TrialQuest(
        title: '本を買って智慧を得よ',
        description: '本を一冊購入せよ',
        suggestedOffering: 2000,
        guardianDeity: GuardianDeity.benzaiten,
      );
      final updated = quest.recordOffering(
        amount: 2500,
        purpose: '技術書を購入',
        note: 'Flutterの本を買った',
      );
      expect(updated.offeringAmount, 2500);
      expect(updated.offeringPurpose, '技術書を購入');
      expect(updated.offeringNote, 'Flutterの本を買った');
      expect(updated.isOfferingRecorded, isTrue);
    });

    test('振り返りを記録できる', () {
      final quest = TrialQuest(
        title: '誰かに贈り物をせよ',
        description: '大切な人に贈り物をせよ',
        suggestedOffering: 5000,
        guardianDeity: GuardianDeity.kisshoten,
      );
      final updated = quest.recordReflection(
        '相手がとても喜んでくれて、自分も幸せな気持ちになった',
      );
      expect(updated.reflection, '相手がとても喜んでくれて、自分も幸せな気持ちになった');
      expect(updated.isReflectionRecorded, isTrue);
    });

    test('喜捨と振り返りの両方が完了するとクエスト完了', () {
      final quest = TrialQuest(
        title: '己への投資を使え',
        description: '自分への投資に金を使え',
        suggestedOffering: 10000,
        guardianDeity: GuardianDeity.bishamonten,
      );
      var updated = quest.recordOffering(amount: 12000, purpose: 'ジム入会', note: '健康への投資');
      updated = updated.recordReflection('自己投資の大切さを実感した');
      expect(updated.isCompleted, isTrue);
    });
  });
}
