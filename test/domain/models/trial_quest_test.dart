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

    // ── 未試験メソッドの単体試験 ──

    group('fromJson', () {
      test('完全なJSONから復元できる', () {
        final json = {
          'title': '誰かと食事を共にせよ',
          'description': '友人や家族と食事をし、会計を済ませよ',
          'suggestedOffering': 3000,
          'guardianDeity': 'daikokuten',
          'offeringAmount': 2500,
          'offeringPurpose': '技術書を購入',
          'offeringNote': 'Flutterの本',
          'reflection': '良い経験だった',
          'review': 'よくやった',
          'receiptImagePath': '/tmp/receipt.png',
        };
        final quest = TrialQuest.fromJson(json);
        expect(quest.title, '誰かと食事を共にせよ');
        expect(quest.description, '友人や家族と食事をし、会計を済ませよ');
        expect(quest.suggestedOffering, 3000);
        expect(quest.guardianDeity, GuardianDeity.daikokuten);
        expect(quest.offeringAmount, 2500);
        expect(quest.offeringPurpose, '技術書を購入');
        expect(quest.offeringNote, 'Flutterの本');
        expect(quest.reflection, '良い経験だった');
        expect(quest.review, 'よくやった');
        expect(quest.receiptImagePath, '/tmp/receipt.png');
      });

      test('欠損キーはフォールバック値になる', () {
        final json = <String, dynamic>{};
        final quest = TrialQuest.fromJson(json);
        expect(quest.title, '');
        expect(quest.description, '');
        expect(quest.suggestedOffering, 0);
        expect(quest.guardianDeity, GuardianDeity.daikokuten);
        expect(quest.offeringAmount, isNull);
        expect(quest.offeringPurpose, isNull);
        expect(quest.offeringNote, isNull);
        expect(quest.reflection, isNull);
        expect(quest.review, isNull);
        expect(quest.receiptImagePath, isNull);
      });

      test('存在しない守護神名は大黒天にフォールバックする', () {
        final json = {
          'title': '試練',
          'description': '説明',
          'suggestedOffering': 1000,
          'guardianDeity': 'nonexistent_deity',
        };
        final quest = TrialQuest.fromJson(json);
        expect(quest.guardianDeity, GuardianDeity.daikokuten);
      });
    });

    group('toJson', () {
      test('全フィールドをJSONに変換できる', () {
        final quest = TrialQuest(
          title: '本を買って智慧を得よ',
          description: '本を一冊購入せよ',
          suggestedOffering: 2000,
          guardianDeity: GuardianDeity.benzaiten,
          offeringAmount: 2500,
          offeringPurpose: '技術書',
          offeringNote: 'メモ',
          reflection: '振り返り',
          review: '講評',
          receiptImagePath: '/path/to/img.png',
        );
        final json = quest.toJson();
        expect(json['title'], '本を買って智慧を得よ');
        expect(json['description'], '本を一冊購入せよ');
        expect(json['suggestedOffering'], 2000);
        expect(json['guardianDeity'], 'benzaiten');
        expect(json['offeringAmount'], 2500);
        expect(json['offeringPurpose'], '技術書');
        expect(json['offeringNote'], 'メモ');
        expect(json['reflection'], '振り返り');
        expect(json['review'], '講評');
        expect(json['receiptImagePath'], '/path/to/img.png');
      });

      test('nullフィールドはキー自体は存在する', () {
        final quest = TrialQuest(
          title: '試練',
          description: '説明',
          suggestedOffering: 1000,
          guardianDeity: GuardianDeity.kisshoten,
        );
        final json = quest.toJson();
        // キーは存在するが値がnull
        expect(json.containsKey('offeringAmount'), isTrue);
        expect(json['offeringAmount'], isNull);
        expect(json.containsKey('offeringPurpose'), isTrue);
        expect(json['offeringPurpose'], isNull);
      });
    });

    group('withReview', () {
      test('講評を設定しても他フィールドは不変', () {
        final quest = TrialQuest(
          title: '誰かに贈り物をせよ',
          description: '大切な人に贈り物をせよ',
          suggestedOffering: 5000,
          guardianDeity: GuardianDeity.kisshoten,
          offeringAmount: 4500,
          offeringPurpose: '花束',
          offeringNote: '母の日',
          reflection: '喜んでもらえた',
          receiptImagePath: '/tmp/flower.png',
        );
        final reviewed = quest.withReview('素晴らしい行いです');
        // 講評が設定されている
        expect(reviewed.review, '素晴らしい行いです');
        // 他フィールドは不変
        expect(reviewed.title, quest.title);
        expect(reviewed.description, quest.description);
        expect(reviewed.suggestedOffering, quest.suggestedOffering);
        expect(reviewed.guardianDeity, quest.guardianDeity);
        expect(reviewed.offeringAmount, quest.offeringAmount);
        expect(reviewed.offeringPurpose, quest.offeringPurpose);
        expect(reviewed.offeringNote, quest.offeringNote);
        expect(reviewed.reflection, quest.reflection);
        expect(reviewed.receiptImagePath, quest.receiptImagePath);
        // 元のインスタンスは変更されていない（不変性）
        expect(quest.review, isNull);
      });
    });

    group('recordOffering', () {
      test('receiptImagePathを指定して喜捨を記録できる', () {
        final quest = TrialQuest(
          title: '誰かと食事を共にせよ',
          description: '友人や家族と食事をし、会計を済ませよ',
          suggestedOffering: 3000,
          guardianDeity: GuardianDeity.daikokuten,
        );
        final updated = quest.recordOffering(
          amount: 2500,
          purpose: '食事',
          note: 'イタリアン',
          receiptImagePath: '/tmp/receipt.jpg',
        );
        expect(updated.offeringAmount, 2500);
        expect(updated.offeringPurpose, '食事');
        expect(updated.offeringNote, 'イタリアン');
        expect(updated.receiptImagePath, '/tmp/receipt.jpg');
        expect(updated.isOfferingRecorded, isTrue);
      });

      test('receiptImagePath未指定時は既存値が維持される', () {
        final quest = TrialQuest(
          title: '試練',
          description: '説明',
          suggestedOffering: 1000,
          guardianDeity: GuardianDeity.daikokuten,
          receiptImagePath: '/tmp/existing.png',
        );
        final updated = quest.recordOffering(
          amount: 500,
          purpose: 'テスト',
        );
        // receiptImagePath未指定でも既存パスが引き継がれる
        expect(updated.receiptImagePath, '/tmp/existing.png');
      });
    });

    test('offeringAmount=0 で isOfferingRecorded が true になる（0はnullと異なる）', () {
      final quest = TrialQuest(
        title: '試練',
        description: '説明',
        suggestedOffering: 1000,
        guardianDeity: GuardianDeity.daikokuten,
        offeringAmount: 0,
      );
      // 0はnullではないのでisOfferingRecordedはtrue
      expect(quest.offeringAmount, 0);
      expect(quest.isOfferingRecorded, isTrue);
    });
  });
}
