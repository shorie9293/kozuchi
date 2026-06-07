import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:kozuchi/features/trial_quest/presentation/screens/trial_quest_screen.dart';
import 'package:kozuchi/domain/models/trial_quest.dart';
import 'package:kozuchi/domain/models/player_model.dart';
import 'package:kozuchi/domain/models/guardian_deity.dart';

void main() {
  group('TrialQuestScreen', () {
    testWidgets('試練のタイトルと説明が表示される', (tester) async {
      final quest = TrialQuest(
        title: '誰かと食事を共にせよ',
        description: '友人や家族と食事をし、会計を済ませよ',
        suggestedOffering: 3000,
        guardianDeity: GuardianDeity.daikokuten,
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

      expect(find.text('誰かと食事を共にせよ'), findsOneWidget);
      expect(find.text('友人や家族と食事をし、会計を済ませよ'), findsOneWidget);
    });

    testWidgets('推奨喜捨額が表示される', (tester) async {
      final quest = TrialQuest(
        title: '本を買って智慧を得よ',
        description: '本を一冊購入せよ',
        suggestedOffering: 2000,
        guardianDeity: GuardianDeity.benzaiten,
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

      expect(find.textContaining('喜捨目安'), findsOneWidget);
      expect(find.textContaining('2,000'), findsOneWidget);
    });

    testWidgets('発行守護神が表示される', (tester) async {
      final quest = TrialQuest(
        title: '誰かに贈り物をせよ',
        description: '大切な人に贈り物をせよ',
        suggestedOffering: 5000,
        guardianDeity: GuardianDeity.kisshoten,
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

      expect(find.textContaining('吉祥天'), findsOneWidget);
    });

    testWidgets('喜捨入力画面に遷移できる', (tester) async {
      final quest = TrialQuest(
        title: '己への投資を使え',
        description: '自分への投資に金を使え',
        suggestedOffering: 10000,
        guardianDeity: GuardianDeity.bishamonten,
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

      expect(find.text('喜捨を記録する'), findsOneWidget);
      await tester.tap(find.text('喜捨を記録する'));
      await tester.pumpAndSettle();
      expect(find.text('喜捨の記録'), findsOneWidget);
    });

    testWidgets('喜捨完了後は振り返り画面に遷移できる', (tester) async {
      final quest = TrialQuest(
        title: '誰かと食事を共にせよ',
        description: '友人と食事を共にせよ',
        suggestedOffering: 3000,
        guardianDeity: GuardianDeity.daikokuten,
      ).recordOffering(amount: 3000, purpose: '友人との食事', note: '楽しかった');
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

      expect(find.text('振り返りを書く'), findsOneWidget);
      await tester.tap(find.text('振り返りを書く'));
      await tester.pumpAndSettle();
      expect(find.text('振り返り'), findsOneWidget);
    });

    testWidgets('WidgetKeyが設定されている', (tester) async {
      final quest = TrialQuest(
        title: '試練',
        description: '説明',
        suggestedOffering: 1000,
        guardianDeity: GuardianDeity.daikokuten,
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

      expect(find.byKey(const Key('trial_quest_screen')), findsOneWidget);
    });
  });
}
