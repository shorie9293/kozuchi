import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kozuchi/domain/models/monthly_budget.dart';
import 'package:kozuchi/features/budget/presentation/widgets/spending_pace_widget.dart';
import 'package:kozuchi/features/shared/data/budget_repository.dart';
import 'package:kozuchi/screens/main_screen.dart';

/// ホーム画面（MainScreen）への支出ペース・月末着地予測の配線を検証する。
///
/// 注意: MainScreen は WashiBackground（AnimationController..repeat()）を含むため
/// pumpAndSettle はタイムアウトする。pump(Duration) で進めること。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: 'https://test.supabase.co',
        anonKey: 'test-key',
      );
    } catch (_) {}
  });

  Future<void> pumpMainScreen(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: MainScreen()));
    // 初期化（予算・支出・デイリークエスト読込）を進める
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  testWidgets('予算未設定なら支出ペースカードは表示されない', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await pumpMainScreen(tester);

    expect(find.byType(SpendingPaceWidget), findsNothing);
  });

  testWidgets('予算設定済みなら支出ペースと月末着地予測が表示される', (tester) async {
    final month = MonthlyBudget.currentYearMonth();
    SharedPreferences.setMockInitialValues({});
    const repo = BudgetRepository();
    await repo.saveBudget(MonthlyBudget(yearMonth: month, amount: 100000));
    await repo.saveMonthlySpending(month, 30000);

    await pumpMainScreen(tester);

    expect(find.byType(SpendingPaceWidget), findsOneWidget);
    expect(find.byKey(SpendingPaceWidget.forecastKey), findsOneWidget);
    expect(find.textContaining('着地見込み'), findsOneWidget);
  });
}
