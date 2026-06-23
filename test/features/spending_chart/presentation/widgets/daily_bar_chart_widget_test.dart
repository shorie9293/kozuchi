import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/spending_chart/data/daily_spending_data.dart';
import 'package:kozuchi/features/spending_chart/presentation/widgets/daily_bar_chart_widget.dart';

void main() {
  // 週間データ（7日分）
  final weekData = const [
    DailySpendingData(day: '月', amount: 1200),
    DailySpendingData(day: '火', amount: 3400),
    DailySpendingData(day: '水', amount: 2100),
    DailySpendingData(day: '木', amount: 5600),
    DailySpendingData(day: '金', amount: 4300),
    DailySpendingData(day: '土', amount: 7800),
    DailySpendingData(day: '日', amount: 2500),
  ];

  final previousWeekData = const [
    DailySpendingData(day: '月', amount: 1500),
    DailySpendingData(day: '火', amount: 2800),
    DailySpendingData(day: '水', amount: 1900),
    DailySpendingData(day: '木', amount: 5200),
    DailySpendingData(day: '金', amount: 3800),
    DailySpendingData(day: '土', amount: 8100),
    DailySpendingData(day: '日', amount: 3000),
  ];

  Widget buildTestWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: 400,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  group('DailyBarChartWidget', () {
    testWidgets('should render with current period only', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          DailyBarChartWidget(
            currentPeriod: weekData,
          ),
        ),
      );

      // 棒グラフの存在確認
      expect(find.byKey(const Key('daily_bar_chart')), findsOneWidget);
      expect(find.byKey(const Key('daily_bar_chart_canvas')), findsOneWidget);

      // 曜日ラベルが表示される
      for (final data in weekData) {
        expect(find.text(data.day), findsWidgets);
      }
    });

    testWidgets('should render with current and previous period', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          DailyBarChartWidget(
            currentPeriod: weekData,
            previousPeriod: previousWeekData,
          ),
        ),
      );

      // 凡例が表示される
      expect(find.text('当期'), findsOneWidget);
      expect(find.text('前期'), findsOneWidget);
    });

    testWidgets('should display label when provided', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const DailyBarChartWidget(
            currentPeriod: [
              DailySpendingData(day: '月', amount: 1000),
            ],
            label: '今週の支出',
          ),
        ),
      );

      expect(find.text('今週の支出'), findsOneWidget);
    });

    testWidgets('should return empty when no data', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const DailyBarChartWidget(
            currentPeriod: [],
          ),
        ),
      );

      // 棒グラフは表示されない
      expect(find.byKey(const Key('daily_bar_chart')), findsNothing);
    });

    testWidgets('should handle single day data', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const DailyBarChartWidget(
            currentPeriod: [
              DailySpendingData(day: '月', amount: 5000),
            ],
          ),
        ),
      );

      expect(find.byKey(const Key('daily_bar_chart')), findsOneWidget);
      expect(find.text('月'), findsOneWidget);
    });

    testWidgets('should handle large amount values', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const DailyBarChartWidget(
            currentPeriod: [
              DailySpendingData(day: '1', amount: 50000),
              DailySpendingData(day: '2', amount: 120000),
            ],
          ),
        ),
      );

      // レンダリングがクラッシュしないことを確認
      expect(find.byKey(const Key('daily_bar_chart')), findsOneWidget);
    });

    testWidgets('should handle previous period with different days',
        (tester) async {
      // 前期の方が日数が多いケース
      await tester.pumpWidget(
        buildTestWidget(
          DailyBarChartWidget(
            currentPeriod: const [
              DailySpendingData(day: '月', amount: 1000),
              DailySpendingData(day: '火', amount: 2000),
            ],
            previousPeriod: const [
              DailySpendingData(day: '月', amount: 900),
              DailySpendingData(day: '火', amount: 1800),
              DailySpendingData(day: '水', amount: 2700),
            ],
          ),
        ),
      );

      // クラッシュせずに表示される
      expect(find.byKey(const Key('daily_bar_chart')), findsOneWidget);
    });

    testWidgets('should use custom colors when provided', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          DailyBarChartWidget(
            currentPeriod: const [
              DailySpendingData(day: '月', amount: 1000),
            ],
            previousPeriod: const [
              DailySpendingData(day: '月', amount: 500),
            ],
            currentBarColor: Colors.blue,
            previousBarColor: Colors.grey,
          ),
        ),
      );

      expect(find.byKey(const Key('daily_bar_chart')), findsOneWidget);
    });

    testWidgets('should not show legend when no previous period',
        (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const DailyBarChartWidget(
            currentPeriod: [
              DailySpendingData(day: '月', amount: 1000),
            ],
          ),
        ),
      );

      // 前期の凡例が出ない
      expect(find.text('当期'), findsNothing);
      expect(find.text('前期'), findsNothing);
    });
  });

  group('DailySpendingData', () {
    test('should create instance with day and amount', () {
      const data = DailySpendingData(day: '月', amount: 3500);
      expect(data.day, '月');
      expect(data.amount, 3500);
    });

    test('should support toString for debugging', () {
      const data = DailySpendingData(day: '火', amount: 1200);
      expect(data.toString(), contains('火'));
      expect(data.toString(), contains('1200'));
    });

    test('should support equality by reference (const)', () {
      const data1 = DailySpendingData(day: '月', amount: 1000);
      const data2 = DailySpendingData(day: '月', amount: 1000);
      // const コンストラクタなので同一インスタンス
      expect(identical(data1, data2), isTrue);
    });
  });
}
