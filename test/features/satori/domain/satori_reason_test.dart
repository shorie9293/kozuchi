import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/level_stage.dart';
import 'package:kozuchi/features/satori/domain/satori_reason.dart';

void main() {
  group('SatoriReason.forIncrease', () {
    test('段階突破（レベル1→2）は開眼理由を返す', () {
      final reason = SatoriReason.forIncrease(
        SatoriContext.generic(
          previousStage: LevelStage.shoTenborin,
          newStage: LevelStage.engi,
        ),
      );
      expect(reason, '新たな開眼 — 金は縁として巡る');
    });

    test('段階突破（レベル2→MAX）は究極理由を返す', () {
      final reason = SatoriReason.forIncrease(
        SatoriContext.generic(
          previousStage: LevelStage.engi,
          newStage: LevelStage.kuu,
        ),
      );
      expect(reason, '究極の悟り — 所有の幻を見破る');
    });

    test('段階突破が最優先（倍率が高くても段階突破理由が優先）', () {
      // 倍率2.0で深い内省だが、レベル1→2の段階突破
      final reason = SatoriReason.forIncrease(
        SatoriContext.reflectionReview(
          expMultiplier: 2.0,
          previousStage: LevelStage.shoTenborin,
          newStage: LevelStage.engi,
        ),
      );
      expect(reason, '新たな開眼 — 金は縁として巡る');
    });

    test('深い内省（倍率1.8以上）は深き内省の悟り', () {
      final reason = SatoriReason.forIncrease(
        SatoriContext.reflectionReview(expMultiplier: 2.0),
      );
      expect(reason, '深き内省の悟り');
    });

    test('倍率1.8以上（境界値）', () {
      final reason = SatoriReason.forIncrease(
        SatoriContext.reflectionReview(expMultiplier: 1.8),
      );
      expect(reason, '深き内省の悟り');
    });

    test('善き振り返り（倍率1.3以上1.8未満）', () {
      final reason = SatoriReason.forIncrease(
        SatoriContext.reflectionReview(expMultiplier: 1.5),
      );
      expect(reason, '善き振り返りの恵み');
    });

    test('倍率1.3（境界値）は善き振り返りの恵み', () {
      final reason = SatoriReason.forIncrease(
        SatoriContext.reflectionReview(expMultiplier: 1.3),
      );
      expect(reason, '善き振り返りの恵み');
    });

    test('大口支出（10,000円以上）は惜しみなき喜捨', () {
      final reason = SatoriReason.forIncrease(
        SatoriContext.reflectionReview(
          expMultiplier: 1.0,
          offeringAmount: 15000,
        ),
      );
      expect(reason, '惜しみなき喜捨');
    });

    test('中口支出（5,000円以上10,000円未満）は気前よき布施', () {
      final reason = SatoriReason.forIncrease(
        SatoriContext.reflectionReview(
          expMultiplier: 1.0,
          offeringAmount: 6000,
        ),
      );
      expect(reason, '気前よき布施');
    });

    test('低倍率（0.7以下）は無駄遣いの自覚', () {
      final reason = SatoriReason.forIncrease(
        SatoriContext.reflectionReview(
          expMultiplier: 0.6,
          offeringAmount: 1000,
        ),
      );
      expect(reason, '無駄遣いの自覚');
    });

    test('デフォルトは善き布施の実践', () {
      final reason = SatoriReason.forIncrease(
        SatoriContext.reflectionReview(
          expMultiplier: 1.0,
          offeringAmount: 1000,
        ),
      );
      expect(reason, '善き布施の実践');
    });

    test('弁財天ボーナスは智慧の蔵書ボーナス', () {
      final reason = SatoriReason.forIncrease(
        SatoriContext.careerCoachBonus(bookTitle: 'テストの書'),
      );
      expect(reason, '智慧の蔵書ボーナス');
    });

    test('genericは悟りの一歩', () {
      final reason = SatoriReason.forIncrease(
        SatoriContext.generic(),
      );
      expect(reason, '悟りの一歩');
    });
  });

  group('SatoriReason.forDecrease', () {
    test('ピンチペナルティは金銭感覚の乱れ', () {
      final reason = SatoriReason.forDecrease(
        const SatoriContext(triggerType: SatoriTriggerType.pinchPenalty),
      );
      expect(reason, '金銭感覚の乱れ');
    });

    test('汎用減少は執着の逆戻り', () {
      final reason = SatoriReason.forDecrease(
        SatoriContext.generic(),
      );
      expect(reason, '執着の逆戻り');
    });
  });

  group('SatoriContext', () {
    test('reflectionReviewファクトリが正しいtriggerTypeを設定する', () {
      final ctx = SatoriContext.reflectionReview(
        advisorLabel: 'テスト',
        expMultiplier: 1.5,
        offeringAmount: 3000,
      );
      expect(ctx.triggerType, SatoriTriggerType.reflectionReview);
      expect(ctx.advisorLabel, 'テスト');
      expect(ctx.expMultiplier, 1.5);
      expect(ctx.offeringAmount, 3000);
    });

    test('careerCoachBonusファクトリが正しいtriggerTypeを設定する', () {
      final ctx = SatoriContext.careerCoachBonus(bookTitle: '名著');
      expect(ctx.triggerType, SatoriTriggerType.careerCoachBonus);
      expect(ctx.advisorLabel, contains('名著'));
    });

    test('careerCoachBonusでbookTitleがnullの場合も動作する', () {
      final ctx = SatoriContext.careerCoachBonus();
      expect(ctx.triggerType, SatoriTriggerType.careerCoachBonus);
      expect(ctx.advisorLabel, '弁財天');
    });

    test('genericファクトリが正しいtriggerTypeを設定する', () {
      final ctx = SatoriContext.generic();
      expect(ctx.triggerType, SatoriTriggerType.generic);
    });
  });
}
