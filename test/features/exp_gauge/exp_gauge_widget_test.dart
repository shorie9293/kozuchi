import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:kozuchi/features/exp_gauge/presentation/widgets/exp_gauge_widget.dart';
import 'package:kozuchi/domain/models/player_model.dart';

void main() {
  group('ExpGaugeWidget', () {
    testWidgets('EXPゲージが表示される', (tester) async {
      final player = PlayerModel(exp: 30);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpGaugeWidget(player: player),
          ),
        ),
      );
      expect(find.text('🧘 EXP（悟りゲージ）'), findsOneWidget);
      expect(find.textContaining('30'), findsOneWidget);
    });

    testWidgets('レベル1の段階が表示される', (tester) async {
      final player = PlayerModel(exp: 10);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpGaugeWidget(player: player),
          ),
        ),
      );
      expect(find.text('レベル1'), findsOneWidget);
      expect(find.text('金は「貯めるもの」→「流すもの」'), findsOneWidget);
    });

    testWidgets('レベル2の段階が表示される', (tester) async {
      final player = PlayerModel(exp: 60);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpGaugeWidget(player: player),
          ),
        ),
      );
      expect(find.text('レベル2'), findsOneWidget);
      expect(find.text('使った金は消えず、誰かの元へ「縁」として巡る'), findsOneWidget);
    });

    testWidgets('レベルMAXの段階が表示される', (tester) async {
      final player = PlayerModel(exp: 120);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpGaugeWidget(player: player),
          ),
        ),
      );
      expect(find.text('レベルMAX'), findsOneWidget);
    });

    testWidgets('3段階のマイルストーンが表示される', (tester) async {
      final player = PlayerModel(exp: 50);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpGaugeWidget(player: player),
          ),
        ),
      );
      expect(find.text('レベル1'), findsOneWidget);
      expect(find.text('レベル2'), findsOneWidget);
      expect(find.text('レベルMAX'), findsOneWidget);
    });

    testWidgets('WidgetKeyが設定されている', (tester) async {
      final player = PlayerModel(exp: 30);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpGaugeWidget(player: player),
          ),
        ),
      );
      expect(find.byKey(const Key('exp_gauge_widget')), findsOneWidget);
    });

    testWidgets('EXP progress bar width matches ratio', (tester) async {
      final player = PlayerModel(exp: 50);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpGaugeWidget(player: player),
          ),
        ),
      );
      // The bar fill FractionallySizedBox has widthFactor = 50/100 = 0.5
      // and its child Container has a gradient decoration (unique from milestone markers)
      expect(
        find.byWidgetPredicate(
          (w) => w is FractionallySizedBox &&
              (w.widthFactor! - 0.5).abs() < 0.01 &&
              w.child is Container &&
              (w.child as Container).decoration is BoxDecoration &&
              ((w.child as Container).decoration as BoxDecoration).gradient != null,
        ),
        findsOneWidget,
      );
    });

    testWidgets('EXP progress bar shows 0 width when exp is 0', (tester) async {
      final player = PlayerModel(exp: 0);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpGaugeWidget(player: player),
          ),
        ),
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is FractionallySizedBox &&
              (w.widthFactor! - 0.0).abs() < 0.01 &&
              w.child is Container &&
              (w.child as Container).decoration is BoxDecoration &&
              ((w.child as Container).decoration as BoxDecoration).gradient != null,
        ),
        findsOneWidget,
      );
    });

    testWidgets('EXP progress bar caps at 100%', (tester) async {
      final player = PlayerModel(exp: 150);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpGaugeWidget(player: player),
          ),
        ),
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is FractionallySizedBox &&
              (w.widthFactor! - 1.0).abs() < 0.01 &&
              w.child is Container &&
              (w.child as Container).decoration is BoxDecoration &&
              ((w.child as Container).decoration as BoxDecoration).gradient != null,
        ),
        findsOneWidget,
      );
    });

    testWidgets('Stage badges show reach/unreach state', (tester) async {
      final player = PlayerModel(exp: 30);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpGaugeWidget(player: player),
          ),
        ),
      );
      // With exp=30, stage is shoTenborin (index 0).
      // 'レベル1' (shoTenborin) → reached (bold, since 0 >= 0)
      // 'レベル2' (engi) → unreached (not bold, since 0 < 1)
      // 'レベルMAX' (kuu) → unreached (not bold, since 0 < 2)
      final shoTenborinText = tester.widget<Text>(
        find.text('レベル1', skipOffstage: false),
      );
      expect(shoTenborinText.style?.fontWeight, FontWeight.bold);

      final engiText = tester.widget<Text>(
        find.text('レベル2', skipOffstage: false),
      );
      expect(engiText.style?.fontWeight, FontWeight.normal);

      final kuuText = tester.widget<Text>(
        find.text('レベルMAX', skipOffstage: false),
      );
      expect(kuuText.style?.fontWeight, FontWeight.normal);
    });

    testWidgets('Current stage description is shown', (tester) async {
      final player = PlayerModel(exp: 10);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpGaugeWidget(player: player),
          ),
        ),
      );
      // exp=10 → stage is shoTenborin
      // Widget shows '現在: レベル1' and the description text
      expect(find.text('現在: レベル1'), findsOneWidget);
      expect(find.text('金は「貯めるもの」→「流すもの」'), findsOneWidget);
    });
  });
}
