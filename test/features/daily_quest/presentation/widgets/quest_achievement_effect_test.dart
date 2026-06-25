import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/daily_quest/presentation/widgets/quest_achievement_effect.dart';

void main() {
  group('QuestAchievementEffect', () {
    testWidgets('全達成モードで「全クエスト達成！」が表示される', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Center(
            child: QuestAchievementEffect(
              showAllComplete: true,
              expGained: 200,
            ),
          ),
        ),
      ));

      // アニメーション開始直後
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('全クエスト達成！'), findsOneWidget);
      expect(find.text('EXP +200'), findsOneWidget);
    });

    testWidgets('単一達成モードで「クエスト達成！」が表示される', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Center(
            child: QuestAchievementEffect(
              showAllComplete: false,
              expGained: 80,
            ),
          ),
        ),
      ));

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('クエスト達成！'), findsOneWidget);
      expect(find.text('EXP +80'), findsOneWidget);
    });

    testWidgets('EXPが指定されていない場合はEXP表示が省略される',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Center(
            child: QuestAchievementEffect(),
          ),
        ),
      ));

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('全クエスト達成！'), findsOneWidget);
      // EXPは表示されない
      expect(find.textContaining('EXP'), findsNothing);
    });

    testWidgets('アニメーション完了時にonCompleteが呼ばれる', (tester) async {
      bool completed = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: QuestAchievementEffect(
              onComplete: () => completed = true,
            ),
          ),
        ),
      ));

      // アニメーションを最後まで進める（1200ms）
      await tester.pump(const Duration(milliseconds: 1300));
      // pumpAndSettleはアニメーション終了を待つ
      await tester.pumpAndSettle();

      expect(completed, isTrue);
    });

    testWidgets('粒子（スター）が表示される', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Center(
            child: QuestAchievementEffect(),
          ),
        ),
      ));

      await tester.pump(const Duration(milliseconds: 600));

      // スターアイコンが複数表示される
      expect(find.byIcon(Icons.star), findsWidgets);
    });
  });
}
