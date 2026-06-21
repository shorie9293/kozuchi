import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:kozuchi/features/hp_bar/presentation/widgets/hp_bar_widget.dart';
import 'package:kozuchi/domain/models/player_model.dart';

void main() {
  group('HpBarWidget', () {
    testWidgets('HP残高が表示される', (tester) async {
      final player = PlayerModel(hp: 100000);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HpBarWidget(player: player),
          ),
        ),
      );
      expect(find.text('💰 残高（HP）'), findsOneWidget);
      expect(find.text('¥100,000'), findsOneWidget);
    });

    testWidgets('生活防衛ラインが表示される', (tester) async {
      final player = PlayerModel(hp: 100000);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HpBarWidget(player: player),
          ),
        ),
      );
      expect(find.text('生活防衛ライン ¥30,000'), findsOneWidget);
    });

    testWidgets('ピンチ状態（HP低下時）に警告が表示される', (tester) async {
      final player = PlayerModel(hp: 25000);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HpBarWidget(player: player),
          ),
        ),
      );
      expect(find.text('⚠️ ピンチ状態 — 執着の餓えに気をつけよ'), findsOneWidget);
    });

    testWidgets('通常時はピンチ警告が表示されない', (tester) async {
      final player = PlayerModel(hp: 50000);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HpBarWidget(player: player),
          ),
        ),
      );
      expect(find.text('⚠️ ピンチ状態 — 執着の餓えに気をつけよ'), findsNothing);
    });

    testWidgets('WidgetKeyが設定されている', (tester) async {
      final player = PlayerModel(hp: 100000);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HpBarWidget(player: player),
          ),
        ),
      );
      expect(find.byKey(const Key('hp_bar_widget')), findsOneWidget);
    });

    testWidgets('HP bar widthFactor is proportional when HP > 50%', (tester) async {
      final player = PlayerModel(hp: 80000);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HpBarWidget(player: player),
          ),
        ),
      );
      // hpRatio = 80000 / 100000 = 0.8
      final fractionBoxes = find.byType(FractionallySizedBox);
      final hpBarBox = fractionBoxes.at(0);
      final FractionallySizedBox widget = tester.widget(hpBarBox);
      expect(widget.widthFactor, closeTo(0.8, 0.01));
    });

    testWidgets('HP bar widthFactor is proportional when HP is 25-50%', (tester) async {
      final player = PlayerModel(hp: 30000);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HpBarWidget(player: player),
          ),
        ),
      );
      // hpRatio = 30000 / 100000 = 0.3
      final fractionBoxes = find.byType(FractionallySizedBox);
      final hpBarBox = fractionBoxes.at(0);
      final FractionallySizedBox widget = tester.widget(hpBarBox);
      expect(widget.widthFactor, closeTo(0.3, 0.01));
    });

    testWidgets('HP bar shows danger/pinch state when HP <= 25%', (tester) async {
      final player = PlayerModel(hp: 15000);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HpBarWidget(player: player),
          ),
        ),
      );
      // hpRatio = 15000 / 100000 = 0.15, and isPinchState = true
      final fractionBoxes = find.byType(FractionallySizedBox);
      final hpBarBox = fractionBoxes.at(0);
      final FractionallySizedBox widget = tester.widget(hpBarBox);
      expect(widget.widthFactor, closeTo(0.15, 0.01));
      // Pinch warning should show
      expect(find.text('⚠️ ピンチ状態 — 執着の餓えに気をつけよ'), findsOneWidget);
    });

    testWidgets('HP bar shows minimum width when HP is 0', (tester) async {
      final player = PlayerModel(hp: 0);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HpBarWidget(player: player),
          ),
        ),
      );
      // hpRatio = 0 / 100000 = 0.0
      final fractionBoxes = find.byType(FractionallySizedBox);
      final hpBarBox = fractionBoxes.at(0);
      final FractionallySizedBox widget = tester.widget(hpBarBox);
      expect(widget.widthFactor, closeTo(0.0, 0.01));
    });
  });
}
