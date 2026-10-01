import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/features/installment/data/installment_repository.dart';
import 'package:kozuchi/features/installment/presentation/installment_app_keys.dart';
import 'package:kozuchi/features/installment/presentation/screens/upcoming_billing_screen.dart';

/// 支払い予定画面（UpcomingBillingScreen）の試練。
///
/// `now` を固定注入して DateTime.now() 依存を排除し、決定論的に検証する。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 10, 2);
  const repository = InstallmentRepository();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpUpcoming(
    WidgetTester tester, {
    DateTime? nowArg,
    int initialWithinDays = 30,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: UpcomingBillingScreen(
          repository: repository,
          now: nowArg ?? now,
          initialWithinDays: initialWithinDays,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('プランもサブスクも無いときは空状態・合計¥0を表示する', (tester) async {
    await pumpUpcoming(tester);

    expect(find.byKey(InstallmentAppKeys.upcomingScreen), findsOneWidget);
    expect(find.byKey(InstallmentAppKeys.upcomingEmpty), findsOneWidget);
    expect(find.text('¥0'), findsOneWidget);
  });

  testWidgets('サブスクを1件登録すると請求額が一覧に出て合計に反映する', (tester) async {
    await repository.addSubscription(
      purpose: '動画サブスク',
      category: '趣味',
      amount: 1200,
      billingDay: 5,
      startDate: DateTime(2026, 9, 1),
      id: 's1',
    );
    await pumpUpcoming(tester);

    // 2026/10/2 基準 → 次回請求 10/5（3日後、30日以内）
    expect(find.byKey(InstallmentAppKeys.upcomingBillingTile('s1')), findsOneWidget);
    expect(find.text('¥1,200'), findsNWidgets(3)); // 合計・グループ合計・行
    expect(
      tester.widget<Text>(find.byKey(InstallmentAppKeys.upcomingTotal)).data,
      '¥1,200',
    );
    expect(find.text('件数 1件'), findsOneWidget);
  });

  testWidgets('分割払いプランを1件登録すると次回請求額が一覧に出る', (tester) async {
    await repository.addPlan(
      purpose: '冷蔵庫',
      category: '家電',
      totalAmount: 3000,
      installmentCount: 3,
      startDate: DateTime(2026, 10, 5),
      id: 'p1',
    );
    await pumpUpcoming(tester);

    // 2026/10/2 基準 → 次回支払 10/5、月額 ¥1,000
    expect(find.byKey(InstallmentAppKeys.upcomingBillingTile('p1')), findsOneWidget);
    expect(find.text('¥1,000'), findsNWidgets(3)); // 合計・グループ合計・行
    expect(
      tester.widget<Text>(find.byKey(InstallmentAppKeys.upcomingTotal)).data,
      '¥1,000',
    );
    expect(find.text('🧾'), findsOneWidget);
  });

  testWidgets('同日の2件は同じ日付グループにまとまりサブスクは🔄で表示する', (tester) async {
    await repository.addSubscription(
      purpose: '動画サブスク',
      category: '趣味',
      amount: 500,
      billingDay: 5,
      startDate: DateTime(2026, 9, 1),
      id: 's1',
    );
    await repository.addPlan(
      purpose: '冷蔵庫',
      category: '家電',
      totalAmount: 3000,
      installmentCount: 3,
      startDate: DateTime(2026, 10, 5),
      id: 'p1',
    );
    await pumpUpcoming(tester);

    expect(find.byKey(InstallmentAppKeys.upcomingDateGroup('20261005')), findsOneWidget);
    expect(find.byKey(InstallmentAppKeys.upcomingBillingTile('s1')), findsOneWidget);
    expect(find.byKey(InstallmentAppKeys.upcomingBillingTile('p1')), findsOneWidget);
    expect(find.text('🔄'), findsOneWidget);
    expect(find.text('🧾'), findsOneWidget);
    // 日付ヘッダ
    expect(find.text('10月5日'), findsOneWidget);
    // 合計 ¥1,500 ・ 件数 2件
    expect(find.text('¥1,500'), findsNWidgets(2)); // 合計・グループ合計
    expect(
      tester.widget<Text>(find.byKey(InstallmentAppKeys.upcomingTotal)).data,
      '¥1,500',
    );
    expect(find.text('件数 2件'), findsOneWidget);
  });

  testWidgets('期間チップを7日に切り替えると20日後の請求が消える', (tester) async {
    await repository.addPlan(
      purpose: '冷蔵庫',
      category: '家電',
      totalAmount: 3000,
      installmentCount: 3,
      startDate: DateTime(2026, 10, 22),
      id: 'p1',
    );
    await pumpUpcoming(tester);

    expect(find.text('¥1,000'), findsNWidgets(3)); // 合計・グループ合計・行
    expect(find.byKey(InstallmentAppKeys.upcomingWindowChip(7)), findsOneWidget);

    await tester.tap(find.byKey(InstallmentAppKeys.upcomingWindowChip(7)));
    await tester.pumpAndSettle();

    expect(find.byKey(InstallmentAppKeys.upcomingBillingTile('p1')), findsNothing);
    expect(find.byKey(InstallmentAppKeys.upcomingEmpty), findsOneWidget);
    expect(find.text('¥0'), findsOneWidget);
  });

  testWidgets('期間チップを30日に戻すと20日後の請求が再び現れる', (tester) async {
    await repository.addPlan(
      purpose: '冷蔵庫',
      category: '家電',
      totalAmount: 3000,
      installmentCount: 3,
      startDate: DateTime(2026, 10, 22),
      id: 'p1',
    );
    await pumpUpcoming(tester);

    await tester.tap(find.byKey(InstallmentAppKeys.upcomingWindowChip(7)));
    await tester.pumpAndSettle();
    expect(find.byKey(InstallmentAppKeys.upcomingBillingTile('p1')), findsNothing);

    await tester.tap(find.byKey(InstallmentAppKeys.upcomingWindowChip(30)));
    await tester.pumpAndSettle();

    expect(find.byKey(InstallmentAppKeys.upcomingBillingTile('p1')), findsOneWidget);
    expect(find.text('¥1,000'), findsWidgets);
  });

  testWidgets('now を固定注入すれば決定論的に表示される', (tester) async {
    await repository.addSubscription(
      purpose: '動画サブスク',
      category: '趣味',
      amount: 900,
      billingDay: 15,
      startDate: DateTime(2026, 9, 1),
      id: 's1',
    );
    // now を 2026/10/10 に固定 → 次回請求は 10/15
    await pumpUpcoming(tester, nowArg: DateTime(2026, 10, 10));

    expect(find.byKey(InstallmentAppKeys.upcomingBillingTile('s1')), findsOneWidget);
    expect(find.byKey(InstallmentAppKeys.upcomingDateGroup('20261015')), findsOneWidget);
    expect(find.text('¥900'), findsWidgets);
  });
}
