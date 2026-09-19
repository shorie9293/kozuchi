import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/budget/domain/spending_pace.dart';

void main() {
  group('SpendingPaceLevel', () {
    test('label が仕様どおり', () {
      expect(SpendingPaceLevel.unknown.label, '判定不能');
      expect(SpendingPaceLevel.comfortable.label, '余裕');
      expect(SpendingPaceLevel.onTrack.label, '適正');
      expect(SpendingPaceLevel.caution.label, '要注意');
      expect(SpendingPaceLevel.critical.label, '超過確実');
      expect(SpendingPaceLevel.exceeded.label, '超過中');
    });

    test('emoji が仕様どおり', () {
      expect(SpendingPaceLevel.unknown.emoji, '⏳');
      expect(SpendingPaceLevel.comfortable.emoji, '🟢');
      expect(SpendingPaceLevel.onTrack.emoji, '🔵');
      expect(SpendingPaceLevel.caution.emoji, '🟡');
      expect(SpendingPaceLevel.critical.emoji, '🟠');
      expect(SpendingPaceLevel.exceeded.emoji, '🔴');
    });
  });

  group('formatAmount', () {
    test('3桁カンマ区切り', () {
      expect(formatAmount(0), '0');
      expect(formatAmount(999), '999');
      expect(formatAmount(1000), '1,000');
      expect(formatAmount(99200), '99,200');
      expect(formatAmount(1234567), '1,234,567');
      expect(formatAmount(-5000), '-5,000');
    });
  });

  group('SpendingPace', () {
    SpendingPace make({
      int monthlyBudget = 100000,
      int totalSpent = 50000,
      int elapsedDays = 15,
      int daysInMonth = 30,
      int remainingDays = 16,
      double dailyPace = 3333.3333333333335,
      int projectedTotal = 100000,
      int projectedBalance = 0,
      int recommendedDailyPace = 3125,
      int overPacePerDay = 208,
      int? daysUntilBudgetEmpty = 3,
      SpendingPaceLevel level = SpendingPaceLevel.onTrack,
    }) =>
        SpendingPace(
          monthlyBudget: monthlyBudget,
          totalSpent: totalSpent,
          elapsedDays: elapsedDays,
          daysInMonth: daysInMonth,
          remainingDays: remainingDays,
          dailyPace: dailyPace,
          projectedTotal: projectedTotal,
          projectedBalance: projectedBalance,
          recommendedDailyPace: recommendedDailyPace,
          overPacePerDay: overPacePerDay,
          daysUntilBudgetEmpty: daysUntilBudgetEmpty,
          level: level,
        );

    test('isBudgetSet: 予算100000→true, 0→false', () {
      expect(make(monthlyBudget: 100000).isBudgetSet, isTrue);
      expect(make(monthlyBudget: 0).isBudgetSet, isFalse);
    });

    test('canForecast: 予算設定+経過1日→true / 予算未設定→false / 経過0日→false', () {
      expect(make(monthlyBudget: 100000, elapsedDays: 1).canForecast, isTrue);
      expect(make(monthlyBudget: 0).canForecast, isFalse);
      expect(make(monthlyBudget: 100000, elapsedDays: 0).canForecast, isFalse);
    });

    test('isOverpaceProjected: 着地120000>予算100000→true / 着地100000→false', () {
      expect(make(projectedTotal: 120000).isOverpaceProjected, isTrue);
      expect(make(projectedTotal: 100000).isOverpaceProjected, isFalse);
    });

    test('projectedUsageRatio: 120000/100000=1.2 / 予算0→0.0', () {
      expect(make(projectedTotal: 120000).projectedUsageRatio, closeTo(1.2, 1e-9));
      expect(make(monthlyBudget: 0, projectedTotal: 50000).projectedUsageRatio,
          0.0);
    });

    test('paceLabel: dailyPace=3200 → 「1日あたり ¥3,200 ペース」', () {
      expect(make(dailyPace: 3200.0).paceLabel, '1日あたり ¥3,200 ペース');
    });

    test('forecastLabel: projectedTotal=99200 → 「このペースだと月末 ¥99,200 着地見込み」',
        () {
      expect(make(projectedTotal: 99200).forecastLabel,
          'このペースだと月末 ¥99,200 着地見込み');
    });

    test('summaryLabel: 絵文字+label+着地見込みが1行で結合される', () {
      expect(
        make(level: SpendingPaceLevel.caution, projectedTotal: 120000)
            .summaryLabel,
        '🟡 要注意 — このペースだと月末 ¥120,000 着地見込み',
      );
      expect(
        make(level: SpendingPaceLevel.unknown, projectedTotal: 0).summaryLabel,
        '⏳ 判定不能 — このペースだと月末 ¥0 着地見込み',
      );
    });

    test('負値 monthlyBudget → ArgumentError', () {
      expect(
        () => make(monthlyBudget: -1),
        throwsArgumentError,
      );
    });

    test('負値 totalSpent → ArgumentError', () {
      expect(() => make(totalSpent: -1), throwsArgumentError);
    });

    test('負値 elapsedDays → ArgumentError', () {
      expect(() => make(elapsedDays: -1), throwsArgumentError);
    });

    test('負値 daysInMonth → ArgumentError', () {
      expect(() => make(daysInMonth: -1), throwsArgumentError);
    });

    test('負値 remainingDays → ArgumentError', () {
      expect(() => make(remainingDays: -1), throwsArgumentError);
    });

    test('0は許容される（負値のみ禁止）', () {
      expect(
        () => make(
            monthlyBudget: 0,
            totalSpent: 0,
            elapsedDays: 0,
            daysInMonth: 0,
            remainingDays: 0),
        returnsNormally,
      );
    });
  });
}