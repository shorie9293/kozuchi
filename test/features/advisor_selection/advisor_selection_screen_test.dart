import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:kozuchi/features/advisor_selection/presentation/advisor_selection_screen.dart';
import 'package:kozuchi/domain/models/advisor.dart';

void main() {
  group('AdvisorSelectionScreen', () {
    testWidgets('四天のアドバイザーが表示される', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdvisorSelectionScreen(
            onSelected: (_) {},
          ),
        ),
      );
      // skipOffstage: false でGrid内の全要素を検索
      expect(find.text('ライフプランナー', skipOffstage: false), findsOneWidget);
      expect(find.text('キャリアコーチ', skipOffstage: false), findsOneWidget);
      expect(find.text('投資メンター', skipOffstage: false), findsOneWidget);
      expect(find.text('ウェルネスアドバイザー', skipOffstage: false), findsOneWidget);
    });

    testWidgets('各アドバイザーの領分が表示される', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdvisorSelectionScreen(
            onSelected: (_) {},
          ),
        ),
      );
      expect(find.text('福・食・財', skipOffstage: false), findsOneWidget);
      expect(find.text('学び・芸術', skipOffstage: false), findsOneWidget);
      expect(find.text('戦い・勝負', skipOffstage: false), findsOneWidget);
      expect(find.text('美・幸福', skipOffstage: false), findsOneWidget);
    });

    testWidgets('画面タイトルが表示される', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdvisorSelectionScreen(
            onSelected: (_) {},
          ),
        ),
      );
      expect(find.text('アドバイザーを選べ'), findsOneWidget);
      expect(find.textContaining('四天'), findsOneWidget);
    });

    testWidgets('アドバイザーをタップすると選択コールバックが呼ばれる', (tester) async {
      Advisor? selectedDeity;
      await tester.pumpWidget(
        MaterialApp(
          home: AdvisorSelectionScreen(
            onSelected: (deity) {
              selectedDeity = deity;
            },
          ),
        ),
      );

      await tester.tap(find.text('ライフプランナー'));
      expect(selectedDeity, Advisor.lifePlanner);
    });

    testWidgets('WidgetKeyが設定されている', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdvisorSelectionScreen(
            onSelected: (_) {},
          ),
        ),
      );
      expect(find.byKey(const Key('advisorSelectionScreen')), findsOneWidget);
    });

    testWidgets('description text is displayed', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdvisorSelectionScreen(
            onSelected: (_) {},
          ),
        ),
      );
      expect(find.text('契約するアドバイザーを選びなさい'), findsOneWidget);
      expect(
          find.text(
              '四天の神々より1柱を選び、その教えに従って試練に挑め'),
          findsOneWidget);
    });

    testWidgets('each deity card shows emoji', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdvisorSelectionScreen(
            onSelected: (_) {},
          ),
        ),
      );
      // 🪘 appears both in the description box and in ライフプランナー's card
      expect(find.text('🪘', skipOffstage: false), findsAtLeastNWidgets(1));
      expect(find.text('🎵', skipOffstage: false), findsOneWidget);
      expect(find.text('⚔️', skipOffstage: false), findsOneWidget);
      expect(find.text('🌸', skipOffstage: false), findsOneWidget);
    });

    testWidgets('deity card has colored container', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdvisorSelectionScreen(
            onSelected: (_) {},
          ),
        ),
      );
      // Each advisor card has a domain badge Container with a colored decoration.
      // The description box also has a Container with decoration. Verify they exist.
      final decoratedContainers = find.byWidgetPredicate(
        (widget) =>
            widget is Container && widget.decoration != null,
        skipOffstage: false,
      );
      // At least: 1 description Container + 4 domain badge Containers
      expect(decoratedContainers, findsAtLeastNWidgets(5));
      // Also verify exactly 4 advisor cards are rendered as Card widgets
      expect(
        find.byType(Card, skipOffstage: false),
        findsNWidgets(4),
      );
    });

    testWidgets('screen has subtitle about 四天', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdvisorSelectionScreen(
            onSelected: (_) {},
          ),
        ),
      );
      // The subtitle/description contains the phrase '四天'
      expect(find.textContaining('四天'), findsOneWidget);
    });

    testWidgets('tap キャリアコーチ calls back with careerCoach', (tester) async {
      Advisor? selectedDeity;
      await tester.pumpWidget(
        MaterialApp(
          home: AdvisorSelectionScreen(
            onSelected: (deity) {
              selectedDeity = deity;
            },
          ),
        ),
      );

      await tester.tap(find.text('キャリアコーチ'));
      expect(selectedDeity, Advisor.careerCoach);
    });
  });
}
