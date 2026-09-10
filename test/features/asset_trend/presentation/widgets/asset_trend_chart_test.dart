import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/asset_trend/domain/monthly_asset_point.dart';
import 'package:kozuchi/features/asset_trend/presentation/widgets/asset_trend_chart.dart';

void main() {
  group('AssetTrendChart', () {
    testWidgets('データが空の場合はメッセージを表示する', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AssetTrendChart(points: []))),
      );

      expect(find.byKey(const Key('asset_trend_chart_empty')), findsOneWidget);
      expect(find.text('資産推移データがありません'), findsOneWidget);
      expect(find.byType(LineChart), findsNothing);
    });

    testWidgets('データがある場合はLineChartを描画する', (tester) async {
      const points = [
        MonthlyAssetPoint(
          year: 2026, month: 7, income: 200000, expense: 50000, balance: 150000),
        MonthlyAssetPoint(
          year: 2026, month: 8, income: 0, expense: 30000, balance: 120000),
        MonthlyAssetPoint(
          year: 2026, month: 9, income: 0, expense: 20000, balance: 100000),
      ];
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AssetTrendChart(points: points))),
      );

      expect(find.byKey(const Key('asset_trend_chart')), findsOneWidget);
      expect(find.byType(LineChart), findsOneWidget);
    });

    testWidgets('同一残高でもレンジが潰れず描画できる', (tester) async {
      const points = [
        MonthlyAssetPoint(
          year: 2026, month: 8, income: 0, expense: 0, balance: 100000),
        MonthlyAssetPoint(
          year: 2026, month: 9, income: 0, expense: 0, balance: 100000),
      ];
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AssetTrendChart(points: points))),
      );

      expect(find.byType(LineChart), findsOneWidget);
    });
  });
}
