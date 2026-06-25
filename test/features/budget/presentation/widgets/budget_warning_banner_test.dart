import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:kozuchi/features/budget/presentation/widgets/budget_warning_banner.dart';

void main() {
  group('BudgetWarningBanner', () {
    testWidgets('閾値（80%）超過時に警告が表示される', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BudgetWarningBanner(
              spentAmount: 85000,
              budgetAmount: 100000,
              ratio: 0.85,
              threshold: 0.8,
            ),
          ),
        ),
      );
      expect(find.text('⚠️ 飢餓ゾーン警告'), findsOneWidget);
      expect(find.textContaining('そろそろ飢餓ゾーン'), findsOneWidget);
    });

    testWidgets('95%超過時に強い警告が表示される', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BudgetWarningBanner(
              spentAmount: 96000,
              budgetAmount: 100000,
              ratio: 0.96,
              threshold: 0.8,
            ),
          ),
        ),
      );
      expect(find.textContaining('残りわずか'), findsOneWidget);
    });

    testWidgets('予算超過時に最も強い警告が表示される', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BudgetWarningBanner(
              spentAmount: 120000,
              budgetAmount: 100000,
              ratio: 1.2,
              threshold: 0.8,
            ),
          ),
        ),
      );
      expect(find.textContaining('超過しました'), findsOneWidget);
    });

    testWidgets('支出額と予算額が表示される', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BudgetWarningBanner(
              spentAmount: 85000,
              budgetAmount: 100000,
              ratio: 0.85,
              threshold: 0.8,
            ),
          ),
        ),
      );
      // 金額の表示（カンマ区切り）
      expect(find.textContaining('¥85,000'), findsOneWidget);
      expect(find.textContaining('¥100,000'), findsOneWidget);
    });

    testWidgets('残予算が表示される', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BudgetWarningBanner(
              spentAmount: 85000,
              budgetAmount: 100000,
              ratio: 0.85,
              threshold: 0.8,
            ),
          ),
        ),
      );
      expect(find.textContaining('残り ¥15,000'), findsOneWidget);
    });

    testWidgets('予算超過時は超過額が表示される', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BudgetWarningBanner(
              spentAmount: 120000,
              budgetAmount: 100000,
              ratio: 1.2,
              threshold: 0.8,
            ),
          ),
        ),
      );
      expect(find.textContaining('¥20,000 超過'), findsOneWidget);
    });
  });
}
