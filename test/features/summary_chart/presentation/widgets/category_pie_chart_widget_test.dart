import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/summary_chart/domain/category_pie_data.dart';
import 'package:kozuchi/features/summary_chart/presentation/widgets/category_pie_chart_widget.dart';

void main() {
  /// テスト用の基本データ
  final _sampleData = [
    const CategoryPieData(categoryName: '食費', amount: 30000, percentage: 40),
    const CategoryPieData(categoryName: '交通費', amount: 15000, percentage: 20),
    const CategoryPieData(categoryName: '娯楽', amount: 22500, percentage: 30),
    const CategoryPieData(categoryName: '光熱費', amount: 7500, percentage: 10),
  ];

  Widget _buildTestWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(body: child),
    );
  }

  group('CategoryPieChartWidget', () {
    testWidgets('データが空でない場合に描画される', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          CategoryPieChartWidget(data: _sampleData),
        ),
      );

      // fl_chart の PieChart が描画されていることを確認（CustomPaint経由）
      expect(find.byType(CategoryPieChartWidget), findsOneWidget);
    });

    testWidgets('タイトルが表示される', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          const CategoryPieChartWidget(
            data: [
              CategoryPieData(categoryName: '食費', amount: 1000, percentage: 100),
            ],
            title: '週間支出',
          ),
        ),
      );

      expect(find.text('週間支出'), findsOneWidget);
    });

    testWidgets('タイトルがnullの場合は表示されない', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          const CategoryPieChartWidget(
            data: [
              CategoryPieData(categoryName: '食費', amount: 1000, percentage: 100),
            ],
          ),
        ),
      );

      // 「週間支出」というテキストは存在しないはず
      expect(find.text('週間支出'), findsNothing);
    });

    testWidgets('凡例がデフォルトで表示される', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          CategoryPieChartWidget(data: _sampleData),
        ),
      );

      // 各カテゴリ名が凡例に表示されている
      for (final item in _sampleData) {
        expect(find.text(item.categoryName), findsWidgets);
      }
    });

    testWidgets('showLegend=false で凡例が非表示', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          CategoryPieChartWidget(
            data: _sampleData,
            showLegend: false,
          ),
        ),
      );

      // 凡例の外側にはカテゴリ名がテキストとしては現れない
      // （fl_chartのPieChartSectionData内でタイトルとして表示される可能性を除く）
      // showLegend=false でWrapが非表示 → find.textで該当テキストがWrap内にない
      // ただしpie chartのセクションtitleは空文字列なのでfindできないはず
      expect(find.text('食費'), findsNothing);
    });

    testWidgets('空データでもエラーなく描画される', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          const CategoryPieChartWidget(data: []),
        ),
      );

      expect(find.byType(CategoryPieChartWidget), findsOneWidget);
    });

    testWidgets('カテゴリが1つだけでも描画される', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          const CategoryPieChartWidget(
            data: [
              CategoryPieData(categoryName: '食費', amount: 50000, percentage: 100),
            ],
          ),
        ),
      );

      expect(find.byType(CategoryPieChartWidget), findsOneWidget);
      expect(find.text('食費'), findsOneWidget);
    });

    testWidgets('onTouched コールバックが呼ばれる', (tester) async {
      int? touchedIndex;
      await tester.pumpWidget(
        _buildTestWidget(
          CategoryPieChartWidget(
            data: _sampleData,
            onTouched: (index) => touchedIndex = index,
          ),
        ),
      );

      // 凡例の最初のカテゴリをタップ
      await tester.tap(find.text('食費').first);
      await tester.pumpAndSettle();

      // タップ後 touchedIndex が 0（食費のインデックス）になる
      expect(touchedIndex, 0);
    });

    testWidgets('同じ凡例を再タップで解除', (tester) async {
      int? touchedIndex;
      await tester.pumpWidget(
        _buildTestWidget(
          CategoryPieChartWidget(
            data: _sampleData,
            onTouched: (index) => touchedIndex = index,
          ),
        ),
      );

      // 1回目タップ → 選択
      await tester.tap(find.text('食費').first);
      await tester.pumpAndSettle();
      expect(touchedIndex, 0);

      // 2回目タップ → 解除
      await tester.tap(find.text('食費').first);
      await tester.pumpAndSettle();
      expect(touchedIndex, -1);
    });
  });
}
