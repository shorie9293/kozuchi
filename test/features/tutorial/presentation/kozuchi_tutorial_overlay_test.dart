import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/features/tutorial/presentation/kozuchi_tutorial_overlay.dart';
import 'package:kozuchi/features/tutorial/domain/kozuchi_tutorial_step.dart';

void main() {
  group('KozuchiTutorialOverlay', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('吹き出しテキストが表示される', (tester) async {
      const step = KozuchiTutorialStep.welcome;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KozuchiTutorialOverlay(
              step: step,
              child: const Text('子Widget'),
            ),
          ),
        ),
      );

      expect(find.text(step.label), findsOneWidget);
      expect(find.text(step.description), findsOneWidget);
    });

    testWidgets('子Widgetが表示される', (tester) async {
      const step = KozuchiTutorialStep.welcome;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KozuchiTutorialOverlay(
              step: step,
              child: const Text('子Widget'),
            ),
          ),
        ),
      );

      expect(find.text('子Widget'), findsOneWidget);
    });

    testWidgets('「次へ」ボタンと「スキップ」ボタンが存在する', (tester) async {
      const step = KozuchiTutorialStep.welcome; // next has a value → "次へ"
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KozuchiTutorialOverlay(
              step: step,
              child: const Text('子Widget'),
            ),
          ),
        ),
      );

      expect(find.text('次へ'), findsOneWidget);
      expect(find.text('スキップ'), findsOneWidget);
    });

    testWidgets('「スキップ」ボタンをタップすると onComplete が呼ばれる', (tester) async {
      const step = KozuchiTutorialStep.welcome;
      bool called = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KozuchiTutorialOverlay(
              step: step,
              child: const Text('子Widget'),
              onComplete: () => called = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('スキップ'));
      expect(called, isTrue);
    });

    testWidgets('「次へ」ボタンをタップすると onComplete が呼ばれる', (tester) async {
      const step = KozuchiTutorialStep.welcome; // next != null → "次へ"
      bool called = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KozuchiTutorialOverlay(
              step: step,
              child: const Text('子Widget'),
              onComplete: () => called = true,
            ),
          ),
        ),
      );

      expect(find.text('次へ'), findsOneWidget);
      await tester.tap(find.text('次へ'));
      expect(called, isTrue);
    });

    testWidgets('最後のステップでは「始める」ボタンが表示される', (tester) async {
      const step = KozuchiTutorialStep.complete; // next == null → "始める"
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KozuchiTutorialOverlay(
              step: step,
              child: const Text('子Widget'),
            ),
          ),
        ),
      );

      expect(find.text('始める'), findsOneWidget);
      expect(find.text('次へ'), findsNothing);
    });
  });
}
