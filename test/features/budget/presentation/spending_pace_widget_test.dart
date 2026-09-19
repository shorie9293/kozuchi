import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/budget/domain/spending_pace.dart';
import 'package:kozuchi/features/budget/domain/spending_pace_service.dart';
import 'package:kozuchi/features/budget/presentation/widgets/spending_pace_widget.dart';

void main() {
  SpendingPace buildPace({
    int monthlyBudget = 100000,
    int totalSpent = 50000,
    int? elapsedDays,
    int? daysInMonth,
    int? remainingDays,
    double? dailyPace,
    int? projectedTotal,
    int? projectedBalance,
    int? recommendedDailyPace,
    int? overPacePerDay,
    int? daysUntilBudgetEmpty,
    bool omitEmptyDays = false,
    SpendingPaceLevel? level,
  }) {
    final eDays = elapsedDays ?? 10;
    final base = const SpendingPaceService().compute(
      totalSpent: totalSpent,
      monthlyBudget: monthlyBudget,
      now: DateTime(2026, 4, eDays),
    );
    return SpendingPace(
      monthlyBudget: monthlyBudget,
      totalSpent: totalSpent,
      elapsedDays: base.elapsedDays,
      daysInMonth: base.daysInMonth,
      remainingDays: base.remainingDays,
      dailyPace: dailyPace ?? base.dailyPace,
      projectedTotal: projectedTotal ?? base.projectedTotal,
      projectedBalance: projectedBalance ?? base.projectedBalance,
      recommendedDailyPace:
          recommendedDailyPace ?? base.recommendedDailyPace,
      overPacePerDay: overPacePerDay ?? base.overPacePerDay,
      daysUntilBudgetEmpty: omitEmptyDays ? null : (daysUntilBudgetEmpty ?? base.daysUntilBudgetEmpty),
      level: level ?? base.level,
    );
  }

  Future<void> pumpWidget(WidgetTester tester, SpendingPace pace,
      {bool isLoading = false}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SpendingPaceWidget(pace: pace, isLoading: isLoading),
        ),
      ),
    );
  }

  group('ローディング状態', () {
    testWidgets('isLoading時はCircularProgressIndicatorを表示する', (tester) async {
      await pumpWidget(tester, buildPace(), isLoading: true);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(Card), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  });

  group('予算未設定', () {
    testWidgets('予算未設定時は案内メッセージの1行カードを表示する', (tester) async {
      await pumpWidget(tester, buildPace(monthlyBudget: 0));
      expect(find.text('月末着地予測には予算設定が必要です'), findsOneWidget);
      expect(find.byKey(SpendingPaceWidget.forecastKey), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  });

  group('レベル表示', () {
    testWidgets('comfortable レベルは🟢 余裕を表示する', (tester) async {
      // 予算100000、支出20000/10日 → 着地60000（60%）→ 余裕
      await pumpWidget(tester, buildPace(monthlyBudget: 100000, totalSpent: 20000));
      final emojiText = tester.widget<Text>(
        find.descendant(
          of: find.byKey(SpendingPaceWidget.levelKey),
          matching: find.text('🟢'),
        ),
      );
      expect(emojiText.data, '🟢');
      expect(find.descendant(
        of: find.byKey(SpendingPaceWidget.levelKey),
        matching: find.text('余裕'),
      ), findsOneWidget);
    });

    testWidgets('onTrack レベルは🔵 適正を表示する', (tester) async {
      // 着地85000（85%）→ 適正
      await pumpWidget(tester, buildPace(monthlyBudget: 100000, totalSpent: 28400));
      expect(find.descendant(
        of: find.byKey(SpendingPaceWidget.levelKey),
        matching: find.text('🔵'),
      ), findsOneWidget);
      expect(find.descendant(
        of: find.byKey(SpendingPaceWidget.levelKey),
        matching: find.text('適正'),
      ), findsOneWidget);
    });

    testWidgets('caution レベルは🟡 要注意を表示する', (tester) async {
      await pumpWidget(tester,
          buildPace(monthlyBudget: 100000, totalSpent: 36700, elapsedDays: 10, daysInMonth: 30));
      expect(find.descendant(
        of: find.byKey(SpendingPaceWidget.levelKey),
        matching: find.text('🟡'),
      ), findsOneWidget);
      expect(find.descendant(
        of: find.byKey(SpendingPaceWidget.levelKey),
        matching: find.text('要注意'),
      ), findsOneWidget);
    });

    testWidgets('critical レベルは🟠 超過確実を表示する', (tester) async {
      await pumpWidget(tester,
          buildPace(monthlyBudget: 100000, totalSpent: 41000, elapsedDays: 10, daysInMonth: 30));
      expect(find.descendant(
        of: find.byKey(SpendingPaceWidget.levelKey),
        matching: find.text('🟠'),
      ), findsOneWidget);
      expect(find.descendant(
        of: find.byKey(SpendingPaceWidget.levelKey),
        matching: find.text('超過確実'),
      ), findsOneWidget);
    });

    testWidgets('exceeded レベルは🔴 超過中を表示する', (tester) async {
      await pumpWidget(tester,
          buildPace(monthlyBudget: 100000, totalSpent: 110000, elapsedDays: 10, daysInMonth: 30));
      expect(find.descendant(
        of: find.byKey(SpendingPaceWidget.levelKey),
        matching: find.text('🔴'),
      ), findsOneWidget);
      expect(find.descendant(
        of: find.byKey(SpendingPaceWidget.levelKey),
        matching: find.text('超過中'),
      ), findsOneWidget);
    });
  });

  group('通常表示', () {
    testWidgets('forecastLabel を表示する', (tester) async {
      await pumpWidget(tester, buildPace(monthlyBudget: 100000, totalSpent: 20000));
      expect(find.byKey(SpendingPaceWidget.forecastKey), findsOneWidget);
      expect(
        find.textContaining('着地見込み'),
        findsOneWidget,
      );
    });

    testWidgets('paceLabel を表示する', (tester) async {
      await pumpWidget(tester, buildPace(monthlyBudget: 100000, totalSpent: 20000));
      expect(find.byKey(SpendingPaceWidget.paceKey), findsOneWidget);
      expect(find.textContaining('1日あたり'), findsOneWidget);
    });

    testWidgets('バーの値は projectedUsageRatio が clamp される', (tester) async {
      // 着地150000（150%）→ ratio 1.0 にクランプ
      await pumpWidget(tester,
          buildPace(monthlyBudget: 100000, totalSpent: 50000, elapsedDays: 10, daysInMonth: 30));
      final bar = tester.widget<LinearProgressIndicator>(
        find.byKey(SpendingPaceWidget.forecastBarKey),
      );
      expect(bar.value, 1.0);
    });

    testWidgets('バーの値は予算比そのまま（50%）', (tester) async {
      await pumpWidget(tester, buildPace(monthlyBudget: 100000, totalSpent: 20000));
      final bar = tester.widget<LinearProgressIndicator>(
        find.byKey(SpendingPaceWidget.forecastBarKey),
      );
      expect(bar.value, closeTo(0.6, 0.01));
    });
  });

  group('overPacePerDay', () {
    testWidgets('正なら「1日 ¥X 使いすぎ」を表示する', (tester) async {
      await pumpWidget(tester, buildPace(
        monthlyBudget: 100000,
        totalSpent: 50000,
        elapsedDays: 10,
        daysInMonth: 30,
        overPacePerDay: 3000,
      ));
      expect(find.byKey(SpendingPaceWidget.overPaceKey), findsOneWidget);
      expect(find.textContaining('使いすぎ'), findsOneWidget);
    });

    testWidgets('負なら「1日 ¥X 余裕」を表示する', (tester) async {
      await pumpWidget(tester, buildPace(
        monthlyBudget: 100000,
        totalSpent: 20000,
        elapsedDays: 10,
        daysInMonth: 30,
        overPacePerDay: -1500,
      ));
      expect(find.byKey(SpendingPaceWidget.overPaceKey), findsOneWidget);
      // overPaceKey は Text 自体に付くため find.descendant は使えない（ルート除外）
      // レベル行にも「余裕」が出得るため、当該 Text の data を直接検証する
      final overPaceText =
          tester.widget<Text>(find.byKey(SpendingPaceWidget.overPaceKey));
      expect(overPaceText.data, contains('余裕'));
      expect(overPaceText.data, contains('1日 ¥1,500 余裕'));
    });

    testWidgets('0なら表示しない', (tester) async {
      await pumpWidget(tester, buildPace(
        monthlyBudget: 100000,
        totalSpent: 20000,
        overPacePerDay: 0,
      ));
      expect(find.byKey(SpendingPaceWidget.overPaceKey), findsNothing);
    });
  });

  group('daysUntilBudgetEmpty', () {
    testWidgets('値があれば「残り◯日で予算を使い切ります」を表示する', (tester) async {
      await pumpWidget(tester, buildPace(
        monthlyBudget: 100000,
        totalSpent: 20000,
        daysUntilBudgetEmpty: 20,
      ));
      expect(find.byKey(SpendingPaceWidget.emptyDaysKey), findsOneWidget);
      expect(find.textContaining('予算を使い切ります'), findsOneWidget);
    });

    testWidgets('nullなら表示しない', (tester) async {
      await pumpWidget(tester, buildPace(
        monthlyBudget: 100000,
        totalSpent: 20000,
        omitEmptyDays: true,
      ));
      expect(find.byKey(SpendingPaceWidget.emptyDaysKey), findsNothing);
    });
  });
}
