import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:kozuchi/features/satori_gauge/presentation/widgets/satori_gauge_widget.dart';
import 'package:kozuchi/domain/models/player_model.dart';

void main() {
  group('SatoriGaugeWidget', () {
    testWidgets('SATORIゲージが表示される', (tester) async {
      final player = PlayerModel(satori: 30);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SatoriGaugeWidget(player: player),
          ),
        ),
      );
      expect(find.text('🧘 SATORI（悟りゲージ）'), findsOneWidget);
      expect(find.textContaining('30'), findsOneWidget);
    });

    testWidgets('初転法輪の段階が表示される', (tester) async {
      final player = PlayerModel(satori: 10);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SatoriGaugeWidget(player: player),
          ),
        ),
      );
      expect(find.text('初転法輪'), findsOneWidget);
      expect(find.text('金は「貯めるもの」→「流すもの」'), findsOneWidget);
    });

    testWidgets('縁起の段階が表示される', (tester) async {
      final player = PlayerModel(satori: 60);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SatoriGaugeWidget(player: player),
          ),
        ),
      );
      expect(find.text('縁起'), findsOneWidget);
      expect(find.text('使った金は消えず、誰かの元へ「縁」として巡る'), findsOneWidget);
    });

    testWidgets('空の段階が表示される', (tester) async {
      final player = PlayerModel(satori: 120);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SatoriGaugeWidget(player: player),
          ),
        ),
      );
      expect(find.text('空'), findsOneWidget);
    });

    testWidgets('3段階のマイルストーンが表示される', (tester) async {
      final player = PlayerModel(satori: 50);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SatoriGaugeWidget(player: player),
          ),
        ),
      );
      expect(find.text('初転法輪'), findsOneWidget);
      expect(find.text('縁起'), findsOneWidget);
      expect(find.text('空'), findsOneWidget);
    });

    testWidgets('WidgetKeyが設定されている', (tester) async {
      final player = PlayerModel(satori: 30);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SatoriGaugeWidget(player: player),
          ),
        ),
      );
      expect(find.byKey(const Key('satori_gauge_widget')), findsOneWidget);
    });

    testWidgets('SATORI progress bar width matches ratio', (tester) async {
      final player = PlayerModel(satori: 50);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SatoriGaugeWidget(player: player),
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

    testWidgets('SATORI progress bar shows 0 width when satori is 0', (tester) async {
      final player = PlayerModel(satori: 0);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SatoriGaugeWidget(player: player),
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

    testWidgets('SATORI progress bar caps at 100%', (tester) async {
      final player = PlayerModel(satori: 150);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SatoriGaugeWidget(player: player),
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
      final player = PlayerModel(satori: 30);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SatoriGaugeWidget(player: player),
          ),
        ),
      );
      // With satori=30, stage is shoTenborin (index 0).
      // '初転法輪' (shoTenborin) → reached (bold, since 0 >= 0)
      // '縁起' (engi) → unreached (not bold, since 0 < 1)
      // '空' (kuu) → unreached (not bold, since 0 < 2)
      final shoTenborinText = tester.widget<Text>(
        find.text('初転法輪', skipOffstage: false),
      );
      expect(shoTenborinText.style?.fontWeight, FontWeight.bold);

      final engiText = tester.widget<Text>(
        find.text('縁起', skipOffstage: false),
      );
      expect(engiText.style?.fontWeight, FontWeight.normal);

      final kuuText = tester.widget<Text>(
        find.text('空', skipOffstage: false),
      );
      expect(kuuText.style?.fontWeight, FontWeight.normal);
    });

    testWidgets('Current stage description is shown', (tester) async {
      final player = PlayerModel(satori: 10);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SatoriGaugeWidget(player: player),
          ),
        ),
      );
      // satori=10 → stage is shoTenborin
      // Widget shows '現在: 初転法輪' and the description text
      expect(find.text('現在: 初転法輪'), findsOneWidget);
      expect(find.text('金は「貯めるもの」→「流すもの」'), findsOneWidget);
    });
  });
}
