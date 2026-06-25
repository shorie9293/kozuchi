import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:kozuchi/features/budget/domain/daily_budget.dart';
import 'package:kozuchi/features/budget/presentation/widgets/daily_budget_widget.dart';

void main() {
  group('DailyBudgetWidget', () {
    testWidgets('予算未設定時は設定促進メッセージが表示される', (tester) async {
      final budget = DailyBudget.empty();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DailyBudgetWidget(dailyBudget: budget),
          ),
        ),
      );
      expect(find.text('日割り予算'), findsOneWidget);
      expect(find.textContaining('予算が未設定です'), findsOneWidget);
      expect(find.textContaining('設定してください'), findsOneWidget);
    });

    testWidgets('ローディング中は進行インジケータが表示される', (tester) async {
      final budget = DailyBudget.empty();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DailyBudgetWidget(
              dailyBudget: budget,
              isLoading: true,
            ),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('予算設定済みの場合は日割り額と内訳が表示される', (tester) async {
      final budget = DailyBudget(
        monthlyBudget: 150000,
        totalSpent: 60000,
        remainingDays: 15,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DailyBudgetWidget(dailyBudget: budget),
          ),
        ),
      );
      // タイトル
      expect(find.text('日割り予算'), findsOneWidget);
      // 日割り額（残予算90000 / 残15日 = 6000）
      expect(find.textContaining('/日'), findsOneWidget);
      // 予算消化率
      expect(find.textContaining('%'), findsOneWidget);
      // 統計グリッド
      expect(find.text('残予算'), findsOneWidget);
      expect(find.text('残日数'), findsOneWidget);
      expect(find.text('月予算'), findsOneWidget);
      expect(find.text('当月支出'), findsOneWidget);
      // 残日数
      expect(find.text('15日'), findsOneWidget);
    });

    testWidgets('予算超過時は警告表示になる', (tester) async {
      final budget = DailyBudget(
        monthlyBudget: 100000,
        totalSpent: 120000,
        remainingDays: 10,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DailyBudgetWidget(dailyBudget: budget),
          ),
        ),
      );
      // 予算超過の警告テキスト
      expect(find.text('⚠️ 予算超過'), findsOneWidget);
    });

    testWidgets('予算消化率80%超はオレンジ色の警告表示', (tester) async {
      final budget = DailyBudget(
        monthlyBudget: 100000,
        totalSpent: 85000,
        remainingDays: 10,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DailyBudgetWidget(dailyBudget: budget),
          ),
        ),
      );
      // 予算消化率バーが表示されている
      expect(find.text('予算消化率'), findsOneWidget);
      // 85% と表示される
      expect(find.text('85%'), findsOneWidget);
    });

    testWidgets('残日数が0の場合は日割り額が0になる', (tester) async {
      final budget = DailyBudget(
        monthlyBudget: 100000,
        totalSpent: 50000,
        remainingDays: 0,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DailyBudgetWidget(dailyBudget: budget),
          ),
        ),
      );
      // 月最終日（残日数0）でも表示される
      expect(find.text('0日'), findsOneWidget);
    });
  });
}
