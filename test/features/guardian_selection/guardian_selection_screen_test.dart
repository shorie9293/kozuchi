import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:kozuchi/features/guardian_selection/presentation/guardian_selection_screen.dart';
import 'package:kozuchi/domain/models/guardian_deity.dart';

void main() {
  group('GuardianSelectionScreen', () {
    testWidgets('四天の守護神が表示される', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GuardianSelectionScreen(
            onSelected: (_) {},
          ),
        ),
      );
      // skipOffstage: false でGrid内の全要素を検索
      expect(find.text('大黒天', skipOffstage: false), findsOneWidget);
      expect(find.text('弁財天', skipOffstage: false), findsOneWidget);
      expect(find.text('毘沙門天', skipOffstage: false), findsOneWidget);
      expect(find.text('吉祥天', skipOffstage: false), findsOneWidget);
    });

    testWidgets('各守護神の領分が表示される', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GuardianSelectionScreen(
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
          home: GuardianSelectionScreen(
            onSelected: (_) {},
          ),
        ),
      );
      expect(find.text('守護神を選べ'), findsOneWidget);
      expect(find.textContaining('四天'), findsOneWidget);
    });

    testWidgets('守護神をタップすると選択コールバックが呼ばれる', (tester) async {
      GuardianDeity? selectedDeity;
      await tester.pumpWidget(
        MaterialApp(
          home: GuardianSelectionScreen(
            onSelected: (deity) {
              selectedDeity = deity;
            },
          ),
        ),
      );

      await tester.tap(find.text('大黒天'));
      expect(selectedDeity, GuardianDeity.daikokuten);
    });

    testWidgets('WidgetKeyが設定されている', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GuardianSelectionScreen(
            onSelected: (_) {},
          ),
        ),
      );
      expect(find.byKey(const Key('guardianSelectionScreen')), findsOneWidget);
    });

    testWidgets('description text is displayed', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GuardianSelectionScreen(
            onSelected: (_) {},
          ),
        ),
      );
      expect(find.text('契約する守護神を選びなさい'), findsOneWidget);
      expect(
          find.text(
              '四天の神々より1柱を選び、その教えに従って試練に挑め'),
          findsOneWidget);
    });

    testWidgets('each deity card shows emoji', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GuardianSelectionScreen(
            onSelected: (_) {},
          ),
        ),
      );
      // 🪘 appears both in the description box and in 大黒天's card
      expect(find.text('🪘', skipOffstage: false), findsAtLeastNWidgets(1));
      expect(find.text('🎵', skipOffstage: false), findsOneWidget);
      expect(find.text('⚔️', skipOffstage: false), findsOneWidget);
      expect(find.text('🌸', skipOffstage: false), findsOneWidget);
    });

    testWidgets('deity card has colored container', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GuardianSelectionScreen(
            onSelected: (_) {},
          ),
        ),
      );
      // Each guardian card has a domain badge Container with a colored decoration.
      // The description box also has a Container with decoration. Verify they exist.
      final decoratedContainers = find.byWidgetPredicate(
        (widget) =>
            widget is Container && widget.decoration != null,
        skipOffstage: false,
      );
      // At least: 1 description Container + 4 domain badge Containers
      expect(decoratedContainers, findsAtLeastNWidgets(5));
      // Also verify exactly 4 guardian cards are rendered as Card widgets
      expect(
        find.byType(Card, skipOffstage: false),
        findsNWidgets(4),
      );
    });

    testWidgets('screen has subtitle about 四天', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GuardianSelectionScreen(
            onSelected: (_) {},
          ),
        ),
      );
      // The subtitle/description contains the phrase '四天'
      expect(find.textContaining('四天'), findsOneWidget);
    });

    testWidgets('tap 弁財天 calls back with benzaiten', (tester) async {
      GuardianDeity? selectedDeity;
      await tester.pumpWidget(
        MaterialApp(
          home: GuardianSelectionScreen(
            onSelected: (deity) {
              selectedDeity = deity;
            },
          ),
        ),
      );

      await tester.tap(find.text('弁財天'));
      expect(selectedDeity, GuardianDeity.benzaiten);
    });
  });
}
