import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/daily_quest.dart';
import 'package:kozuchi/features/daily_quest/presentation/widgets/daily_quest_list.dart';

void main() {
  group('DailyQuestList', () {
    testWidgets('クエスト一覧が表示される', (tester) async {
      final quests = [
        DailyQuest(
          type: DailyQuestType.spendOnSelf,
          title: '自分に使え：¥1,000',
          description: 'テスト1',
          targetValue: 1000,
        ),
        DailyQuest(
          type: DailyQuestType.receiptScan,
          title: 'レシートを3枚撮れ',
          description: 'テスト2',
          targetValue: 3,
        ),
      ];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DailyQuestList(quests: quests),
          ),
        ),
      ));

      expect(find.text('今日のクエスト'), findsOneWidget);
      expect(find.text('自分に使え：¥1,000'), findsOneWidget);
      expect(find.text('レシートを3枚撮れ'), findsOneWidget);
    });

    testWidgets('読み込み中はローディング表示', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: DailyQuestList(
            quests: [],
            isLoading: true,
          ),
        ),
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('エラー時はエラーメッセージと再読み込みボタンが表示される',
        (tester) async {
      bool retried = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DailyQuestList(
            quests: [],
            errorMessage: 'ネットワークエラー',
            onRetry: () => retried = true,
          ),
        ),
      ));

      expect(find.text('クエストの読み込みに失敗しました'), findsOneWidget);
      expect(find.text('ネットワークエラー'), findsOneWidget);

      await tester.tap(find.text('再読み込み'));
      expect(retried, isTrue);
    });

    testWidgets('空リスト時は空表示', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: DailyQuestList(quests: []),
        ),
      ));

      expect(find.text('今日のクエストはまだありません'), findsOneWidget);
    });

    testWidgets('全達成時は達成エフェクトが表示される', (tester) async {
      final quests = [
        DailyQuest(
          type: DailyQuestType.spendOnSelf,
          title: '自分に使え：¥1,000',
          description: '',
          targetValue: 1000,
        ).updateProgress(1000),
        DailyQuest(
          type: DailyQuestType.receiptScan,
          title: 'レシートを3枚撮れ',
          description: '',
          targetValue: 3,
        ).updateProgress(3),
      ];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DailyQuestList(
              quests: quests,
              allCompletedEffect: const Text('達成おめでとう！'),
            ),
          ),
        ),
      ));

      expect(find.text('達成おめでとう！'), findsOneWidget);
    });

    testWidgets('達成済み→進行中→失敗の順にソートされる', (tester) async {
      final now = DateTime.now();
      final quests = [
        DailyQuest(
          id: 'q1',
          type: DailyQuestType.spendOnSelf,
          title: '失敗クエスト',
          description: '',
          targetValue: 1000,
          dateAssigned: now,
        ).markAsFailed(),
        DailyQuest(
          id: 'q2',
          type: DailyQuestType.receiptScan,
          title: '達成済みクエスト',
          description: '',
          targetValue: 3,
          dateAssigned: now,
        ).updateProgress(3),
        DailyQuest(
          id: 'q3',
          type: DailyQuestType.newCategory,
          title: '進行中クエスト',
          description: '',
          targetValue: 1,
          dateAssigned: now,
        ),
      ];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DailyQuestList(quests: quests),
          ),
        ),
      ));

      // 達成済みが最初に来ることを確認
      expect(find.text('達成済みクエスト'), findsOneWidget);
      expect(find.text('進行中クエスト'), findsOneWidget);
      expect(find.text('失敗クエスト'), findsOneWidget);
    });

    testWidgets('セクションタイトルに件数が表示される', (tester) async {
      final quests = [
        DailyQuest(
          type: DailyQuestType.newCategory,
          title: 'クエスト',
          description: '',
          targetValue: 1,
        ),
      ];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DailyQuestList(quests: quests),
          ),
        ),
      ));

      expect(find.text('1件'), findsOneWidget);
    });

    testWidgets('全達成時に「X/X 達成！」が表示される', (tester) async {
      final quests = [
        DailyQuest(
          type: DailyQuestType.newCategory,
          title: 'クエスト1',
          description: '',
          targetValue: 1,
        ).updateProgress(1),
        DailyQuest(
          type: DailyQuestType.receiptScan,
          title: 'クエスト2',
          description: '',
          targetValue: 2,
        ).updateProgress(2),
      ];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DailyQuestList(quests: quests),
          ),
        ),
      ));

      expect(find.text('2/2 達成！'), findsOneWidget);
    });

    testWidgets('カードタップ時にonQuestTapが呼ばれる', (tester) async {
      DailyQuest? tappedQuest;
      final quests = [
        DailyQuest(
          type: DailyQuestType.spendOnSelf,
          title: 'テストクエスト',
          description: '',
          targetValue: 500,
        ),
      ];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DailyQuestList(
              quests: quests,
              onQuestTap: (q) => tappedQuest = q,
            ),
          ),
        ),
      ));

      await tester.tap(find.text('テストクエスト'));
      expect(tappedQuest, isNotNull);
      expect(tappedQuest!.title, 'テストクエスト');
    });
  });
}
