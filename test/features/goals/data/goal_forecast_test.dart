import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/goals/data/goal.dart';
import 'package:kozuchi/features/goals/data/goal_forecast.dart';

/// テスト用の Goal を生成
Goal _goal({
  String? deadline,
  required int targetAmount,
  required int currentAmount,
  required DateTime createdAt,
  String status = 'active',
}) {
  return Goal(
    id: 'g1',
    userId: 'u1',
    title: '目標',
    targetAmount: targetAmount,
    deadline: deadline,
    currentAmount: currentAmount,
    status: status,
    progressPercent: null,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

void main() {
  group('GoalForecast モデル', () {
    test('monthlyPace は経過月数で割った貯蓄ペース', () {
      const forecast = GoalForecast(
        monthlyPace: 30000,
        requiredMonthly: null,
        forecastDate: null,
        isOnTrack: true,
        remainingAmount: 30000,
        monthsRemaining: 1,
      );
      expect(forecast.monthlyPace, 30000);
      expect(forecast.requiredMonthly, isNull);
      expect(forecast.isOnTrack, isTrue);
      expect(forecast.remainingAmount, 30000);
    });

    test('forecastSummary は達成見込み日を整形する', () {
      const forecast = GoalForecast(
        monthlyPace: 30000,
        requiredMonthly: null,
        forecastDate: null,
        isOnTrack: true,
        remainingAmount: 10000,
        monthsRemaining: 1,
      );
      final withDate = GoalForecast(
        monthlyPace: 30000,
        requiredMonthly: null,
        forecastDate: DateTime(2026, 12, 31),
        isOnTrack: true,
        remainingAmount: 10000,
        monthsRemaining: 1,
      );
      expect(withDate.forecastSummary(null), contains('12月'));
      expect(withDate.forecastSummary(null), contains('2026年'));
      expect(forecast.forecastSummary(null), isNot(contains('達成')));
    });

    test('forecastSummary は null で日本語メッセージ', () {
      const forecast = GoalForecast(
        monthlyPace: 0,
        requiredMonthly: null,
        forecastDate: null,
        isOnTrack: false,
        remainingAmount: 10000,
        monthsRemaining: null,
      );
      expect(forecast.forecastSummary(null), isNotEmpty);
    });
  });

  group('GoalForecastService.forecast - 基本算出', () {
    test('月次ペースから達成見込み日を算出する', () {
      // 2026-01-01 作成・現在 2026-07-01・6ヶ月で 60000 貯めた = 月 10000
      // 残 30000 → あと 3 ヶ月 → 達成見込み 2026-10-01
      final goal = _goal(
        targetAmount: 90000,
        currentAmount: 60000,
        createdAt: DateTime(2026, 1, 1),
      );
      final now = DateTime(2026, 7, 1);

      final forecast = GoalForecastService.forecast(goal, now: now);

      expect(forecast.monthlyPace, closeTo(10000, 0.01));
      expect(forecast.remainingAmount, 30000);
      expect(forecast.forecastDate, DateTime(2026, 10, 1));
      expect(forecast.forecastSummary(null), contains('2026年10月'));
      expect(forecast.isOnTrack, isTrue);
    });

    test('current >= target の場合は即達成', () {
      final goal = _goal(
        targetAmount: 50000,
        currentAmount: 50000,
        createdAt: DateTime(2026, 1, 1),
      );
      final now = DateTime(2026, 7, 1);

      final forecast = GoalForecastService.forecast(goal, now: now);

      expect(forecast.remainingAmount, 0);
      expect(forecast.forecastDate, isNull);
      expect(forecast.monthlyPace, 0);
      expect(forecast.forecastSummary(null), contains('達成'));
    });
  });

  group('GoalForecastService.forecast - 期限', () {
    test('期限より遅い場合は isOnTrack = false + 必要月額を算出', () {
      // 2026-01-01 作成・2026-07-01 時点で月ペース 10000
      // 期限 2026-08-31・残 60000 → あと 2 ヶ月弱で 60000 貯める必要 → 必要月額 30000
      final goal = _goal(
        deadline: '2026-08-31',
        targetAmount: 120000,
        currentAmount: 60000,
        createdAt: DateTime(2026, 1, 1),
      );
      final now = DateTime(2026, 7, 1);

      final forecast = GoalForecastService.forecast(goal, now: now);

      expect(forecast.monthlyPace, closeTo(10000, 0.01));
      expect(forecast.remainingAmount, 60000);
      expect(forecast.monthsRemaining, 2);
      expect(forecast.requiredMonthly, 30000);
      expect(forecast.isOnTrack, isFalse);
      expect(forecast.forecastSummary(null), contains('月'));
    });

    test('期限までに月次ペースで届く場合は isOnTrack = true', () {
      // 期限 2026-10-31・あと 4 ヶ月弱・残 30000・ペース月 10000 → 届く
      final goal = _goal(
        deadline: '2026-10-31',
        targetAmount: 120000,
        currentAmount: 90000,
        createdAt: DateTime(2026, 1, 1),
      );
      final now = DateTime(2026, 7, 1);

      final forecast = GoalForecastService.forecast(goal, now: now);

      expect(forecast.requiredMonthly, isNull);
      expect(forecast.isOnTrack, isTrue);
    });

    test('期限切れ（deadline 過去）の場合は期限超過メッセージ', () {
      final goal = _goal(
        deadline: '2026-01-31',
        targetAmount: 120000,
        currentAmount: 60000,
        createdAt: DateTime(2025, 1, 1),
      );
      final now = DateTime(2026, 7, 1);

      final forecast = GoalForecastService.forecast(goal, now: now);

      expect(forecast.monthsRemaining, 0);
      expect(forecast.isOnTrack, isFalse);
      expect(forecast.forecastSummary(null), contains('期限'));
    });

    test('期限が非正規形式でも例外を出さない', () {
      final goal = _goal(
        deadline: 'invalid',
        targetAmount: 100000,
        currentAmount: 10000,
        createdAt: DateTime(2026, 1, 1),
      );
      final now = DateTime(2026, 7, 1);

      final forecast = GoalForecastService.forecast(goal, now: now);

      expect(forecast.monthsRemaining, isNull);
      expect(forecast.requiredMonthly, isNull);
      expect(forecast.forecastDate, isNotNull);
    });
  });

  group('GoalForecastService.forecast - フォールバック', () {
    test('completed は即達成扱い', () {
      final goal = _goal(
        targetAmount: 50000,
        currentAmount: 10000,
        createdAt: DateTime(2026, 1, 1),
        status: 'completed',
      );
      final now = DateTime(2026, 7, 1);

      final forecast = GoalForecastService.forecast(goal, now: now);

      expect(forecast.remainingAmount, 0);
      expect(forecast.forecastSummary(null), contains('達成'));
    });

    test('cancelled は非表示メッセージ', () {
      final goal = _goal(
        targetAmount: 50000,
        currentAmount: 10000,
        createdAt: DateTime(2026, 1, 1),
        status: 'cancelled',
      );
      final now = DateTime(2026, 7, 1);

      final forecast = GoalForecastService.forecast(goal, now: now);

      expect(forecast.forecastSummary(null), contains('中止'));
    });

    test('target_amount=0 は予測不能', () {
      final goal = _goal(
        targetAmount: 0,
        currentAmount: 0,
        createdAt: DateTime(2026, 1, 1),
      );
      final now = DateTime(2026, 7, 1);

      final forecast = GoalForecastService.forecast(goal, now: now);

      expect(forecast.forecastSummary(null), contains('設定'));
    });

    test('作成直後（経過 0 ヶ月）はペース未確定', () {
      final goal = _goal(
        targetAmount: 100000,
        currentAmount: 5000,
        createdAt: DateTime(2026, 6, 20),
      );
      final now = DateTime(2026, 7, 1);

      final forecast = GoalForecastService.forecast(goal, now: now);

      expect(forecast.monthlyPace, 0);
      expect(forecast.forecastDate, isNull);
      expect(forecast.forecastSummary(null), isNotEmpty);
      expect(forecast.isOnTrack, isFalse);
    });

    test('現在金額が負でも例外を出さず予測する', () {
      final goal = _goal(
        targetAmount: 100000,
        currentAmount: -20000,
        createdAt: DateTime(2026, 1, 1),
      );
      final now = DateTime(2026, 7, 1);

      final forecast = GoalForecastService.forecast(goal, now: now);

      expect(forecast.remainingAmount, 120000);
      // 月ペース 10000 で達成見込みは 12 ヶ月後
      expect(forecast.forecastDate, DateTime(2027, 7, 1));
    });
  });
}
