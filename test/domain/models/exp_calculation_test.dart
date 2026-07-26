import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/exp_calculation.dart';
import 'package:kozuchi/domain/models/advisor.dart';

void main() {
  group('calculateQuestExpGain', () {
    test('支出額0以下では0を返す', () {
      expect(
        calculateQuestExpGain(
          offeringAmount: 0,
          aiMultiplier: 1.0,
          advisorMultiplier: 1.2,
        ),
        0,
      );
    });

    test('守護神の加護倍率がEXPに適用される（機能的影響）', () {
      // 基準: ¥5000支出 → base = 5 + 5 = 10
      const amount = 5000;
      const ai = 1.0;
      final baseExp = calculateQuestExpGain(
        offeringAmount: amount,
        aiMultiplier: ai,
        advisorMultiplier: Advisor.daikokuten.expMultiplier, // 1.0
      );
      expect(baseExp, 10);

      // 毘沙門天(x1.2)を契約すると+20%の悟りEXPを得る
      final boostedExp = calculateQuestExpGain(
        offeringAmount: amount,
        aiMultiplier: ai,
        advisorMultiplier: Advisor.bishamonten.expMultiplier, // 1.2
      );
      expect(boostedExp, 12);

      // 弁財天(x1.1)を契約すると+10%の悟りEXPを得る
      final midExp = calculateQuestExpGain(
        offeringAmount: amount,
        aiMultiplier: ai,
        advisorMultiplier: Advisor.benzaiten.expMultiplier, // 1.1
      );
      expect(midExp, 11);
    });

    test('AI講評倍率と守護神倍率は乗算される', () {
      final exp = calculateQuestExpGain(
        offeringAmount: 5000, // base 10
        aiMultiplier: 1.5, // 深い内省
        advisorMultiplier: Advisor.bishamonten.expMultiplier, // 1.2
      );
      expect(exp, 18); // 10 * 1.5 * 1.2 = 18
    });
  });
}
