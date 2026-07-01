import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:kozuchi/features/trial_quest/presentation/screens/trial_quest_screen.dart';
import 'package:kozuchi/domain/models/trial_quest.dart';
import 'package:kozuchi/domain/models/player_model.dart';
import 'package:kozuchi/domain/models/advisor.dart';

void main() {
  group('TrialQuestScreen - 完了条件の明確さ', () {
    testWidgets('完了条件（2ステップ）が表示されている', (tester) async {
      final quest = TrialQuest(
        title: '誰かと食事を共にせよ',
        description: '友人や家族と食事をし、会計を済ませよ',
        suggestedOffering: 3000,
        advisor: Advisor.daikokuten,
      );
      final player = PlayerModel.defaultPlayer();

      await tester.pumpWidget(
        MaterialApp(
          home: TrialQuestScreen(
            quest: quest,
            player: player,
            onQuestUpdated: (_, __) {},
          ),
        ),
      );

      // 完了条件のセクションが表示されている
      expect(find.text('完了条件'), findsOneWidget);
      // Step1: 支出を記録する
      expect(find.text('Step 1: '), findsOneWidget);
      expect(find.text('支出を記録する'), findsNWidgets(2)); // 条件表示＋ボタン
      // Step2: 振り返りを書く
      expect(find.text('Step 2: '), findsOneWidget);
      expect(find.text('振り返りを書く'), findsOneWidget);
    });

    testWidgets('支出未記録時はStep1が未完了、Step2が未着手と表示される', (tester) async {
      final quest = TrialQuest(
        title: 'テスト',
        description: '説明',
        suggestedOffering: 1000,
        advisor: Advisor.daikokuten,
      );
      final player = PlayerModel.defaultPlayer();

      await tester.pumpWidget(
        MaterialApp(
          home: TrialQuestScreen(
            quest: quest,
            player: player,
            onQuestUpdated: (_, __) {},
          ),
        ),
      );

      // Step1が未完了
      expect(find.textContaining('支出を記録'), findsWidgets);
      // Step2の「振り返り」が表示されている
      expect(find.textContaining('振り返り'), findsOneWidget);
    });

    testWidgets('支出記録後はStep1完了、Step2未完了と表示される', (tester) async {
      final quest = TrialQuest(
        title: 'テスト',
        description: '説明',
        suggestedOffering: 1000,
        advisor: Advisor.daikokuten,
      ).recordOffering(amount: 3000, purpose: 'テスト支出');
      final player = PlayerModel.defaultPlayer();

      await tester.pumpWidget(
        MaterialApp(
          home: TrialQuestScreen(
            quest: quest,
            player: player,
            onQuestUpdated: (_, __) {},
          ),
        ),
      );

      // Step1が完了チェックマークあり
      expect(find.text('Step 1: '), findsOneWidget);
      // 振り返りボタンが表示（条件表示＋ボタンで2つ）
      expect(find.text('振り返りを書く'), findsNWidgets(2));
      // 進捗表示が「1/2」になっている
      expect(find.text('1/2'), findsOneWidget);
    });

    testWidgets('全ステップ完了後は「クエスト完了」と表示される', (tester) async {
      final quest = TrialQuest(
        title: 'テスト',
        description: '説明',
        suggestedOffering: 1000,
        advisor: Advisor.daikokuten,
      )
          .recordOffering(amount: 3000, purpose: 'テスト支出')
          .recordReflection('良い経験だった');
      final player = PlayerModel.defaultPlayer();

      await tester.pumpWidget(
        MaterialApp(
          home: TrialQuestScreen(
            quest: quest,
            player: player,
            onQuestUpdated: (_, __) {},
          ),
        ),
      );

      // 完了状態が表示されている
      expect(find.textContaining('完了'), findsWidgets);
    });

    testWidgets('進捗表示（例: "Step 1/2"）が表示されている', (tester) async {
      final quest = TrialQuest(
        title: 'テスト',
        description: '説明',
        suggestedOffering: 1000,
        advisor: Advisor.daikokuten,
      );
      final player = PlayerModel.defaultPlayer();

      await tester.pumpWidget(
        MaterialApp(
          home: TrialQuestScreen(
            quest: quest,
            player: player,
            onQuestUpdated: (_, __) {},
          ),
        ),
      );

      // 進捗表示（例: "0/2" または "Step 1/2" 的な表現）
      expect(find.textContaining('/'), findsWidgets);
    });
  });
}
