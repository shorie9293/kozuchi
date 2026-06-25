import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:kozuchi/features/goal_spending/presentation/widgets/goal_spending_gauge.dart';

void main() {
  group('GoalSpendingGauge', () {
    testWidgets('予算設定済みの場合、目標支出の消化率が表示される', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GoalSpendingGauge(
              monthlyBudget: 150000,
              totalSpent: 45000,
              remainingDays: 20,
            ),
          ),
        ),
      );
      // ラベル
      expect(find.text('今月の目標支出'), findsOneWidget);
      // 消化率 30%
      expect(find.text('30%'), findsOneWidget);
      // 残予算
      expect(find.textContaining('残予算'), findsOneWidget);
      // 残日数
      expect(find.textContaining('20日'), findsOneWidget);
      // 月予算
      expect(find.textContaining('月予算'), findsOneWidget);
    });

    testWidgets('予算超過時は警告表示', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GoalSpendingGauge(
              monthlyBudget: 150000,
              totalSpent: 165000,
              remainingDays: 5,
            ),
          ),
        ),
      );
      expect(find.textContaining('予算超過'), findsOneWidget);
      expect(find.text('110%'), findsOneWidget);
    });

    testWidgets('予算未設定時は設定促しを表示', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GoalSpendingGauge(
              monthlyBudget: 0,
              totalSpent: 0,
              remainingDays: 0,
            ),
          ),
        ),
      );
      expect(find.textContaining('目標額を設定'), findsOneWidget);
    });

    testWidgets('onTapBudget コールバックが呼ばれる', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GoalSpendingGauge(
              monthlyBudget: 0,
              totalSpent: 0,
              remainingDays: 0,
              onTapBudget: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.tap(find.textContaining('目標額を設定'));
      expect(tapped, isTrue);
    });

    testWidgets('消化率に応じてバーの色が変わる（緑→黄→橙→赤）', (tester) async {
      // 緑（〜50%）
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GoalSpendingGauge(
              monthlyBudget: 150000,
              totalSpent: 30000,
              remainingDays: 20,
            ),
          ),
        ),
      );
      expect(find.text('20%'), findsOneWidget);

      // 黄（〜80%）
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GoalSpendingGauge(
              monthlyBudget: 150000,
              totalSpent: 105000,
              remainingDays: 10,
            ),
          ),
        ),
      );
      expect(find.text('70%'), findsOneWidget);

      // 赤（超過）
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GoalSpendingGauge(
              monthlyBudget: 100000,
              totalSpent: 120000,
              remainingDays: 3,
            ),
          ),
        ),
      );
      expect(find.textContaining('予算超過'), findsOneWidget);
      expect(find.text('120%'), findsOneWidget);
    });
  });
}
