import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/budget/domain/spending_pace.dart';
import 'package:kozuchi/features/budget/domain/spending_pace_service.dart';

void main() {
  const service = SpendingPaceService();

  group('閾値定数', () {
    test('comfortableThreshold=0.8, criticalThreshold=1.2', () {
      expect(SpendingPaceService.comfortableThreshold, 0.8);
      expect(SpendingPaceService.criticalThreshold, 1.2);
    });
  });

  group('compute 基本計算', () {
    test('2026-09-19（30日月の19日目）: 標準ケース', () {
      // 手計算: daysInMonth=30, elapsed=19, remaining=30-19+1=12
      // totalSpent=50000 → dailyPace=50000/19=2631.5789...
      // projected=(2631.5789*30).round()=(78947.36).round()=78947
      // projectedBalance=100000-78947=21053
      // remainingBudget=50000 → recommended=50000~/12=4166
      // overPace=(2631.5789-4166).round()=(-1534.42).round()=-1534
      // daysUntilBudgetEmpty=(50000/2631.5789).floor()=(19.0).floor()=19
      // projected 78947 <= 100000*0.8=80000 → comfortable
      final r = service.compute(
        totalSpent: 50000,
        monthlyBudget: 100000,
        now: DateTime(2026, 9, 19),
      );
      expect(r.daysInMonth, 30);
      expect(r.elapsedDays, 19);
      expect(r.remainingDays, 12);
      expect(r.dailyPace, closeTo(2631.5789, 0.001));
      expect(r.projectedTotal, 78947);
      expect(r.projectedBalance, 21053);
      expect(r.recommendedDailyPace, 4166);
      expect(r.overPacePerDay, -1534);
      expect(r.daysUntilBudgetEmpty, 19);
      expect(r.level, SpendingPaceLevel.comfortable);
    });
  });

  group('level 判定（閾値境界）', () {
    test('着地がちょうど予算*0.8 → comfortable', () {
      // 手計算: now=1/15, daysInMonth=31, elapsed=15
      // dailyPace=48000/15=3200 → projected=(3200*31).round()=99200
      // 99200 == 100000*0.8=80000? No — 99200 なので comfortable ではない。
      // → 条件満たすよう支出を調整: projected=80000 には
      //   dailyPace=80000/31=2580.645 → totalSpent=dailyPace*15=38709.677 →
      //   round でずれるため、ここは daysInMonth=25 の月を使う:
      //   now=2/15(平年2月), daysInMonth=28? … わかりやすく1月31日中で:
      //   projected=80000 ⇔ dailyPace=80000/31=2580.645… ⇔ totalSpent=38709.677
      //   round後の誤差があるため、テストは projected 検証込みで行う。
      // 確定案: 7月(31日), now=7/16, elapsed=16
      //   totalSpent=41290 → dailyPace=2580.625 → projected=(2580.625*31).round()
      //   = (79999.375).round() = 79999 → 80000 未満 → comfortable
      // 厳密に「ちょうど0.8倍」: projected==80000 が必要。
      //   dailyPace=80000/31 → totalSpent = 80000*16/31 = 41290.32…
      //   実際の dailyPace=41290/16=2580.625 → projected=79999 (1円足りない)
      //   そこで 9月(30日) を使う: projected=80000 ⇔ dailyPace=2580.0
      //   now=9/16, elapsed=16, totalSpent=41280 → dailyPace=2580.0
      //   projected=(2580*30).round()=77400 … これも合わない。
      // 再計算: daysInMonth=30 で projected=80000 ⇔ dailyPace=2666.666…
      //   elapsed=15 なら totalSpent=40000 → dailyPace=2666.666…
      //   projected=(2666.666…*30).round()=(79999.999…).round()=80000
      //   80000 == 100000*0.8 → onTrack ではなく comfortable（> ではない）
      final r = service.compute(
        totalSpent: 40000, // dailyPace=40000/15=2666.666…, 月30日
        monthlyBudget: 100000,
        now: DateTime(2026, 9, 15),
      );
      // 手計算: projected=(2666.666…*30).round()=80000, 80000 <= 0.8*100000=80000
      expect(r.projectedTotal, 80000);
      expect(r.level, SpendingPaceLevel.comfortable);
    });

    test('着地がちょうど0.8倍超の直上 → onTrack', () {
      // 手計算: 月30日, elapsed=15, totalSpent=40001
      //   dailyPace=40001/15=2666.733… → projected=(2666.733…*30).round()
      //   =(80001.999…).round()=80002 > 80000 → onTrack
      final r = service.compute(
        totalSpent: 40001,
        monthlyBudget: 100000,
        now: DateTime(2026, 9, 15),
      );
      expect(r.projectedTotal, 80002);
      expect(r.level, SpendingPaceLevel.onTrack);
    });

    test('着地がちょうど予算ちょうど（1.0倍） → caution', () {
      // 手計算: 月30日, elapsed=10, totalSpent=10000
      //   dailyPace=1000（割り切れる）→ projected=(1000*30).round()=30000
      //   予算30000: 30000 > 0.8*30000=24000 → onTrack（>予算 ではないため caution に堕ちない）
      final r = service.compute(
        totalSpent: 10000,
        monthlyBudget: 30000,
        now: DateTime(2026, 9, 10),
      );
      expect(r.projectedTotal, 30000);
      expect(r.isOverpaceProjected, isFalse);
      expect(r.level, SpendingPaceLevel.onTrack);
    });

    test('着地がちょうど予算*1.2 → caution（> 1.2 でなければ critical でない）', () {
      // 手計算: 月30日, elapsed=15, totalSpent=60000
      //   dailyPace=4000 → projected=(4000*30).round()=120000
      //   120000 > 1.2*100000=120000 は偽 → critical でない
      //   120000 > 100000 → caution
      final r = service.compute(
        totalSpent: 60000,
        monthlyBudget: 100000,
        now: DateTime(2026, 9, 15),
      );
      expect(r.projectedTotal, 120000);
      expect(r.level, SpendingPaceLevel.caution);
    });

    test('着地が1.2倍超 → critical', () {
      // 手計算: 月30日, elapsed=15, totalSpent=60001
      //   dailyPace=60001/15=4000.066… → projected=(4000.066…*30).round()
      //   =(120002.0).round()=120002 > 120000 → critical
      final r = service.compute(
        totalSpent: 60001,
        monthlyBudget: 100000,
        now: DateTime(2026, 9, 15),
      );
      expect(r.projectedTotal, 120002);
      expect(r.level, SpendingPaceLevel.critical);
    });

    test('支出が予算超過済み → exceeded（着地判断より優先）', () {
      // 手計算: totalSpent=100001 > 100000 → 判定順2で即 exceeded
      //   月30日 elapsed=15: dailyPace=6666.733… projected=200002
      final r = service.compute(
        totalSpent: 100001,
        monthlyBudget: 100000,
        now: DateTime(2026, 9, 15),
      );
      expect(r.level, SpendingPaceLevel.exceeded);
      expect(r.projectedTotal, 200002);
    });

    test('支出が予算ぴったり → 判定順2の totalSpent > monthlyBudget は偽 → 着地判断へ', () {
      // 手計算: 月30日 elapsed=15, totalSpent=100000
      //   dailyPace=6666.666… → projected=(6666.666…*30).round()=200000
      //   200000 > 120000 → critical（exceededではない）
      final r = service.compute(
        totalSpent: 100000,
        monthlyBudget: 100000,
        now: DateTime(2026, 9, 15),
      );
      expect(r.level, SpendingPaceLevel.critical);
      expect(r.projectedTotal, 200000);
    });

    test('予算未設定 → unknown', () {
      // 手計算: monthlyBudget=0 → 判定順1で unknown
      final r = service.compute(
        totalSpent: 50000,
        monthlyBudget: 0,
        now: DateTime(2026, 9, 15),
      );
      expect(r.level, SpendingPaceLevel.unknown);
      expect(r.isBudgetSet, isFalse);
      expect(r.canForecast, isFalse);
      expect(r.projectedUsageRatio, 0.0);
      expect(r.recommendedDailyPace, 0);
      expect(r.overPacePerDay, 0);
      expect(r.daysUntilBudgetEmpty, isNull);
    });

    test('予算が負値 → ArgumentError（コンストラクタ検証）', () {
      expect(
        () => service.compute(
          totalSpent: 0,
          monthlyBudget: -100,
          now: DateTime(2026, 9, 15),
        ),
        throwsArgumentError,
      );
    });
  });

  group('月初・月末・2月（閏年）', () {
    test('月初1日目: elapsed=1, remaining=daysInMonth', () {
      // 手計算: 2026-09-01, 月30日: elapsed=1, remaining=30-1+1=30
      //   totalSpent=3000 → dailyPace=3000 → projected=(3000*30).round()=90000
      //   90000 > 80000 → onTrack
      //   remainingBudget=97000 → recommended=97000~/30=3233
      //   overPace=(3000-3233).round()=-233
      //   daysUntilBudgetEmpty=(97000/3000).floor()=(32.33).floor()=32
      final r = service.compute(
        totalSpent: 3000,
        monthlyBudget: 100000,
        now: DateTime(2026, 9, 1),
      );
      expect(r.elapsedDays, 1);
      expect(r.remainingDays, 30);
      expect(r.dailyPace, 3000.0);
      expect(r.projectedTotal, 90000);
      expect(r.recommendedDailyPace, 3233);
      expect(r.overPacePerDay, -233);
      expect(r.daysUntilBudgetEmpty, 32);
      expect(r.level, SpendingPaceLevel.onTrack);
    });

    test('月末最終日: elapsed=daysInMonth, remaining=1', () {
      // 手計算: 2026-09-30, 月30日: elapsed=30, remaining=30-30+1=1
      //   totalSpent=90000 → dailyPace=3000 → projected=(3000*30).round()=90000
      //   90000 > 80000 → onTrack
      //   remainingBudget=10000 → recommended=10000~/1=10000
      //   overPace=(3000-10000).round()=-7000
      //   daysUntilBudgetEmpty=(10000/3000).floor()=(3.33).floor()=3
      final r = service.compute(
        totalSpent: 90000,
        monthlyBudget: 100000,
        now: DateTime(2026, 9, 30),
      );
      expect(r.elapsedDays, 30);
      expect(r.remainingDays, 1);
      expect(r.projectedTotal, 90000);
      expect(r.projectedBalance, 10000);
      expect(r.recommendedDailyPace, 10000);
      expect(r.overPacePerDay, -7000);
      expect(r.daysUntilBudgetEmpty, 3);
      expect(r.level, SpendingPaceLevel.onTrack);
    });

    test('平年2月は28日', () {
      // 手計算: 2026-02-14（平年）: daysInMonth=28, remaining=28-14+1=15
      final r = service.compute(
        totalSpent: 28000,
        monthlyBudget: 100000,
        now: DateTime(2026, 2, 14),
      );
      expect(r.daysInMonth, 28);
      expect(r.remainingDays, 15);
      // 手計算: dailyPace=2000 → projected=(2000*28).round()=56000
      //   56000 <= 80000 → comfortable
      expect(r.projectedTotal, 56000);
      expect(r.level, SpendingPaceLevel.comfortable);
    });

    test('閏年2024年2月は29日、2024-02-29も正常計算', () {
      // 手計算: 2024-02-29（閏年最終日）: daysInMonth=29, elapsed=29, remaining=1
      //   totalSpent=58000 → dailyPace=2000 → projected=(2000*29).round()=58000
      //   58000 <= 80000 → comfortable
      //   remainingBudget=42000 → recommended=42000~/1=42000
      //   overPace=(2000-42000).round()=-40000
      //   daysUntilBudgetEmpty=(42000/2000).floor()=21
      final r = service.compute(
        totalSpent: 58000,
        monthlyBudget: 100000,
        now: DateTime(2024, 2, 29),
      );
      expect(r.daysInMonth, 29);
      expect(r.elapsedDays, 29);
      expect(r.remainingDays, 1);
      expect(r.projectedTotal, 58000);
      expect(r.recommendedDailyPace, 42000);
      expect(r.overPacePerDay, -40000);
      expect(r.daysUntilBudgetEmpty, 21);
      expect(r.level, SpendingPaceLevel.comfortable);
    });

    test('月跨ぎ: 12月は31日', () {
      // 手計算: 2026-12-10: daysInMonth=31, remaining=31-10+1=22
      final r = service.compute(
        totalSpent: 31000,
        monthlyBudget: 100000,
        now: DateTime(2026, 12, 10),
      );
      expect(r.daysInMonth, 31);
      expect(r.remainingDays, 22);
    });
  });

  group('支出0・daysUntilBudgetEmpty 分岐', () {
    test('支出0: dailyPace=0, projected=0, comfortable, daysUntilBudgetEmpty=null',
        () {
      // 手計算: totalSpent=0 → dailyPace=0 → projected=0
      //   0 <= 80000 → comfortable
      //   remainingBudget=100000 → recommended=100000~/16=6250（9/15, 月30日, remaining=16）
      //   overPace=(0-6250).round()=-6250
      //   dailyPace<=0 → daysUntilBudgetEmpty=null
      final r = service.compute(
        totalSpent: 0,
        monthlyBudget: 100000,
        now: DateTime(2026, 9, 15),
      );
      expect(r.dailyPace, 0.0);
      expect(r.projectedTotal, 0);
      expect(r.projectedBalance, 100000);
      expect(r.recommendedDailyPace, 6250);
      expect(r.overPacePerDay, -6250);
      expect(r.daysUntilBudgetEmpty, isNull);
      expect(r.level, SpendingPaceLevel.comfortable);
    });

    test('残予算ちょうど0（支出=予算の半端消費ではなく残0）→ daysUntilBudgetEmpty=0',
        () {
      // 手計算: totalSpent=100000, monthlyBudget=100000 → remaining=0 → 0
      final r = service.compute(
        totalSpent: 100000,
        monthlyBudget: 100000,
        now: DateTime(2026, 9, 15),
      );
      expect(r.daysUntilBudgetEmpty, 0);
      expect(r.recommendedDailyPace, 0);
    });

    test('超過済み → daysUntilBudgetEmpty=0, exceeded', () {
      // 手計算: totalSpent=110000 > 100000 → remaining=-10000<=0 → 0
      final r = service.compute(
        totalSpent: 110000,
        monthlyBudget: 100000,
        now: DateTime(2026, 9, 15),
      );
      expect(r.daysUntilBudgetEmpty, 0);
      expect(r.level, SpendingPaceLevel.exceeded);
    });

    test('daysUntilBudgetEmpty の切り捨て検証', () {
      // 手計算: 9/1, 月30日, totalSpent=1000 → dailyPace=1000
      //   remaining=99000 → (99000/1000).floor()=99
      final r = service.compute(
        totalSpent: 1000,
        monthlyBudget: 100000,
        now: DateTime(2026, 9, 1),
      );
      expect(r.daysUntilBudgetEmpty, 99);
    });
  });

  group('ラベル', () {
    test('paceLabel / forecastLabel / summaryLabel の実値', () {
      // 手計算: 9/15, 月30日, totalSpent=32000 → dailyPace=2133.333…
      //   projected=(2133.333…*30).round()=(63999.99…).round()=64000
      //   paceLabel は dailyPace.round()=2133 → '1日あたり ¥2,133 ペース'
      //   forecastLabel → 'このペースだと月末 ¥64,000 着地見込み'
      //   64000 <= 80000 → comfortable → '🟢 余裕 — …'
      final r = service.compute(
        totalSpent: 32000,
        monthlyBudget: 100000,
        now: DateTime(2026, 9, 15),
      );
      expect(r.paceLabel, '1日あたり ¥2,133 ペース');
      expect(r.forecastLabel, 'このペースだと月末 ¥64,000 着地見込み');
      expect(r.summaryLabel, '🟢 余裕 — このペースだと月末 ¥64,000 着地見込み');
    });
  });
}