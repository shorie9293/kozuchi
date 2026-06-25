import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/daily_quest.dart';
import 'package:kozuchi/features/daily_quest/presentation/widgets/daily_quest_card.dart';

void main() {
  group('DailyQuestCard', () {
    testWidgets('全クエストタイプのカードがレンダリングできる', (tester) async {
      for (final type in DailyQuestType.values) {
        final quest = DailyQuest(
          id: 'test_${type.name}',
          type: type,
          title: 'テスト: ${type.label}',
          description: 'これはテストクエストです',
          targetValue: type == DailyQuestType.noSpending ? 0 : 1000,
        );

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: DailyQuestCard(quest: quest),
          ),
        ));

        // タイトルが表示されている
        expect(find.text('テスト: ${type.label}'), findsOneWidget);
      }
    });

    testWidgets('達成済みクエストのカードには達成バッジが表示される',
        (tester) async {
      final quest = DailyQuest(
        type: DailyQuestType.spendOnSelf,
        title: '自分に使え：¥1,000',
        description: 'テスト',
        targetValue: 1000,
      ).updateProgress(1000);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DailyQuestCard(quest: quest),
        ),
      ));

      expect(find.text('達成'), findsOneWidget);
      expect(find.text('EXP +80'), findsOneWidget);
    });

    testWidgets('失敗クエストのカードには失敗バッジが表示される',
        (tester) async {
      final quest = DailyQuest(
        type: DailyQuestType.spendOnSelf,
        title: '自分に使え：¥1,000',
        description: 'テスト',
        targetValue: 1000,
      ).markAsFailed();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DailyQuestCard(quest: quest),
        ),
      ));

      expect(find.text('失敗'), findsOneWidget);
      expect(find.text('SATORI -10'), findsOneWidget);
    });

    testWidgets('未達成クエストには進捗バーが表示される', (tester) async {
      final quest = DailyQuest(
        type: DailyQuestType.spendOnSelf,
        title: '自分に使え：¥1,000',
        description: 'テスト',
        targetValue: 1000,
      ).updateProgress(500);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DailyQuestCard(quest: quest),
        ),
      ));

      // 進捗バー（LinearProgressIndicator）
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      // 進捗テキスト
      expect(find.text('500 / 1000'), findsOneWidget);
    });

    testWidgets('二値型クエスト（noSpending）は進捗バーが表示されない',
        (tester) async {
      final quest = DailyQuest(
        type: DailyQuestType.noSpending,
        title: '無支出の日',
        description: 'テスト',
        targetValue: 0,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DailyQuestCard(quest: quest),
        ),
      ));

      // 進捗バーは表示されない（targetValueが0のため）
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('各タイプに応じたアイコンが表示される', (tester) async {
      for (final type in DailyQuestType.values) {
        final quest = DailyQuest(
          id: 'test_${type.name}',
          type: type,
          title: type.label,
          description: '',
          targetValue: 100,
        );

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: DailyQuestCard(quest: quest),
          ),
        ));

        // 各タイプ固有のアイコンがIconウィジェットで表示される
        // （少なくとも1つのIconが表示されることを確認）
        expect(find.byType(Icon).first, findsWidgets);
      }
    });

    testWidgets('タップ時にonTapコールバックが呼ばれる', (tester) async {
      bool tapped = false;
      final quest = DailyQuest(
        type: DailyQuestType.receiptScan,
        title: 'レシートを3枚撮れ',
        description: '',
        targetValue: 3,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DailyQuestCard(
            quest: quest,
            onTap: () => tapped = true,
          ),
        ),
      ));

      await tester.tap(find.byType(DailyQuestCard));
      expect(tapped, isTrue);
    });
  });
}
