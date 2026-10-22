import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/features/weekly_quest/domain/models/active_weekly_quest.dart';
import 'package:kozuchi/features/weekly_quest/domain/models/weekly_quest.dart';
import 'package:kozuchi/features/weekly_quest/domain/weekly_quest_progress.dart';
import 'package:kozuchi/features/weekly_quest/presentation/weekly_quest_app_keys.dart';
import 'package:kozuchi/features/weekly_quest/presentation/widgets/weekly_quest_card.dart';

WeeklyQuest quest({String id = 'q1'}) => WeeklyQuest(
      id: id,
      title: '今週は食費を¥8,000以内に',
      description: '節約しよう',
      targetCategory: '食費',
      budgetLimit: 8000,
      currentAvgSpend: 10000,
      difficulty: QuestDifficulty.medium,
      generatedAt: DateTime(2026, 10, 19),
      weekStart: DateTime(2026, 10, 19),
      templateId: 'budgetLimit',
    );

WeeklyQuestProgress progress({
  int spentAmount = 4000,
  int remainingDays = 3,
  bool hasEnded = false,
  WeeklyQuestStatus status = WeeklyQuestStatus.active,
}) =>
    WeeklyQuestProgress(
      quest: quest(),
      spentAmount: spentAmount,
      remainingDays: remainingDays,
      hasEnded: hasEnded,
      status: status,
    );

Widget wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  testWidgets('タイトル・状態チップ・難易度・ratio が progress 由来で表示される', (tester) async {
    await tester.pumpWidget(wrap(WeeklyQuestCard(progress: progress())));
    await tester.pump();

    expect(find.byKey(WeeklyQuestAppKeys.card('q1')), findsOneWidget);
    expect(find.text('今週は食費を¥8,000以内に'), findsOneWidget);
    expect(find.byKey(WeeklyQuestAppKeys.statusChip('q1')), findsOneWidget);
    expect(find.text('挑戦中'), findsOneWidget);
    expect(find.text('中'), findsOneWidget);
    expect(find.text('¥4,000 / ¥8,000'), findsOneWidget);

    final indicator = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(indicator.value, closeTo(0.5, 0.001));
  });

  testWidgets('completed は達成表示になり failed は超過表示になる', (tester) async {
    await tester.pumpWidget(wrap(WeeklyQuestCard(
      progress: progress(
        spentAmount: 3000,
        remainingDays: 0,
        hasEnded: true,
        status: WeeklyQuestStatus.completed,
      ),
    )));
    await tester.pump();

    expect(find.text('達成！'), findsOneWidget);
    expect(find.text('達成！¥5,000 の余裕'), findsOneWidget);

    await tester.pumpWidget(wrap(WeeklyQuestCard(
      progress: progress(
        spentAmount: 10000,
        status: WeeklyQuestStatus.failed,
      ),
    )));
    await tester.pump();

    expect(find.text('超過'), findsOneWidget);
    expect(find.text('¥2,000 超過'), findsOneWidget);
  });

  testWidgets('onTap を渡すとタップで呼ばれる', (tester) async {
    var taps = 0;
    await tester.pumpWidget(wrap(WeeklyQuestCard(
      progress: progress(),
      onTap: () => taps++,
    )));
    await tester.pump();

    await tester.tap(find.byKey(WeeklyQuestAppKeys.card('q1')));
    await tester.pump();

    expect(taps, 1);
  });
}
