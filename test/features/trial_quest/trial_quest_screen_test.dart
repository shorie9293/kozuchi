import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:kozuchi/features/trial_quest/presentation/screens/trial_quest_screen.dart';
import 'package:kozuchi/domain/models/trial_quest.dart';
import 'package:kozuchi/domain/models/player_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/domain/models/advisor.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: 'https://test.supabase.co',
        anonKey: 'test-key',
      );
    } catch (_) {}
  });

  group('TrialQuestScreen', () {
    testWidgets('試練のタイトルと説明が表示される', (tester) async {
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

      expect(find.text('誰かと食事を共にせよ'), findsOneWidget);
      expect(find.text('友人や家族と食事をし、会計を済ませよ'), findsOneWidget);
    });

    testWidgets('推奨支出額が表示される', (tester) async {
      final quest = TrialQuest(
        title: '本を買って智慧を得よ',
        description: '本を一冊購入せよ',
        suggestedOffering: 2000,
        advisor: Advisor.benzaiten,
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

      expect(find.textContaining('支出目安'), findsOneWidget);
      expect(find.textContaining('2,000'), findsOneWidget);
    });

    testWidgets('発行アドバイザーが表示される', (tester) async {
      final quest = TrialQuest(
        title: '誰かに贈り物をせよ',
        description: '大切な人に贈り物をせよ',
        suggestedOffering: 5000,
        advisor: Advisor.kichijoten,
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

    testWidgets('支出入力画面に遷移できる', (tester) async {
      final quest = TrialQuest(
        title: '己への投資を使え',
        description: '自分への投資に金を使え',
        suggestedOffering: 10000,
        advisor: Advisor.bishamonten,
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

      // ElevatedButton.iconのアイコンでタップ
      await tester.tap(find.byIcon(Icons.paid));
      await tester.pumpAndSettle();
      expect(find.text('支出の記録'), findsOneWidget);
    });

    testWidgets('支出完了後は振り返り画面に遷移できる', (tester) async {
      final quest = TrialQuest(
        title: '誰かと食事を共にせよ',
        description: '友人と食事を共にせよ',
        suggestedOffering: 3000,
        advisor: Advisor.daikokuten,
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

      // ElevatedButton.iconのアイコンでタップ
      await tester.tap(find.byIcon(Icons.edit_note).last);
      await tester.pumpAndSettle();
      expect(find.text('振り返り'), findsOneWidget);
    });

    testWidgets('WidgetKeyが設定されている', (tester) async {
      final quest = TrialQuest(
        title: '試練',
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

      expect(find.byKey(const Key('trial_quest_screen')), findsOneWidget);
    });
  });
}
