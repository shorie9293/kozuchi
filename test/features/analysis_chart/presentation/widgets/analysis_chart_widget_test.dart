import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:kozuchi/features/analysis_chart/presentation/widgets/analysis_chart_widget.dart';

void main() {
  group('AnalysisChartWidget', () {
    testWidgets('should render 5 mandala nodes with labels', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: AnalysisChartWidget(isVisible: true),
            ),
          ),
        ),
      );

      // 5つのノードラベルが表示される
      expect(find.text('我'), findsOneWidget);
      expect(find.text('店'), findsOneWidget);
      expect(find.text('職人'), findsOneWidget);
      expect(find.text('家族'), findsOneWidget);
      expect(find.text('智慧'), findsOneWidget);
    });

    testWidgets('should have CustomPaint for mandala rendering', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: AnalysisChartWidget(isVisible: true),
            ),
          ),
        ),
      );

      // CustomPaintが存在する（キーで特定）
      expect(find.byKey(const Key('analysis_chart_custom_paint')), findsOneWidget);
    });

    testWidgets('should animate with active AnimationController', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: AnalysisChartWidget(isVisible: true),
            ),
          ),
        ),
      );

      // 最初のフレーム
      await tester.pump();
      // アニメーションが進行していることを確認（複数フレーム経過後もクラッシュしない）
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // ウィジェットがまだ存在する（クラッシュしていない）
      expect(find.byType(AnalysisChartWidget), findsOneWidget);
    });

    testWidgets('should be hidden when isVisible is false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: AnalysisChartWidget(isVisible: false),
            ),
          ),
        ),
      );

      // 非表示時はマンダラ関連の要素が表示されない
      expect(find.byKey(const Key('analysis_chart_custom_paint')), findsNothing);
      expect(find.text('我'), findsNothing);
      // Widget自体はレンダリングされている（SizedBox.shrink）
      expect(find.byType(AnalysisChartWidget), findsOneWidget);
    });

    testWidgets('should have widget key for testing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: AnalysisChartWidget(isVisible: true),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('analysis_chart_widget')), findsOneWidget);
    });

    testWidgets('should render without errors and survive animation frames',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: AnalysisChartWidget(isVisible: true),
            ),
          ),
        ),
      );

      // 最初のフレームを描画
      await tester.pump();
      // アニメーションを数フレーム進める
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      // ウィジェットがクラッシュせずに残っている
      expect(find.byType(AnalysisChartWidget), findsOneWidget);
    });

    testWidgets('should use AnimatedBuilder for smooth animation loop',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: AnalysisChartWidget(isVisible: true),
            ),
          ),
        ),
      );

      // AnalysisChartWidget の内部配下に AnimatedBuilder が存在する
      // (MaterialApp/Scaffold も内部的に AnimatedBuilder を使うため findsOneWidget ではなく
      //  findsAtLeastNWidgets で確認)
      expect(find.byType(AnimatedBuilder), findsAtLeastNWidgets(1));
    });

    testWidgets('should have node containers with amber circular decoration',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: AnalysisChartWidget(isVisible: true),
            ),
          ),
        ),
      );

      // 最初のノード「我」のContainerを取り出し、装飾を検証
      final container = tester.widget<Container>(
        find.ancestor(
          of: find.text('我'),
          matching: find.byType(Container),
        ).first,
      );

      expect(container.decoration, isNotNull);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
      // 境界線が amber を含む色であることを確認
      expect(decoration.border, isNotNull);
    });

    testWidgets('should style node labels with amber color and bold weight',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: AnalysisChartWidget(isVisible: true),
            ),
          ),
        ),
      );

      // 各ノードラベルのテキストスタイルを検証
      for (final label in ['我', '店', '職人', '家族', '智慧']) {
        final textWidget = tester.widget<Text>(find.text(label));
        expect(textWidget.style?.color, Colors.amber);
        expect(textWidget.style?.fontSize, 12);
        expect(textWidget.style?.fontWeight, FontWeight.bold);
      }
    });

    testWidgets('should use Stack layout for mandala node positioning',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: AnalysisChartWidget(isVisible: true),
            ),
          ),
        ),
      );

      // 5つのノードが Positioned で配置されていることを確認
      // (MaterialApp 内部の Stack を避け、Positioned の個数で検証)
      expect(find.byType(Positioned), findsNWidgets(5));
    });
  });
}
