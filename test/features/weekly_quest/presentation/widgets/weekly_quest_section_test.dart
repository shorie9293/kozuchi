import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/domain/services/expense_repository.dart';
import 'package:kozuchi/features/weekly_quest/data/weekly_quest_generator.dart';
import 'package:kozuchi/features/weekly_quest/data/weekly_quest_store.dart';
import 'package:kozuchi/features/weekly_quest/domain/models/weekly_quest.dart';
import 'package:kozuchi/features/weekly_quest/domain/weekly_quest_period.dart';
import 'package:kozuchi/features/weekly_quest/presentation/state/weekly_quest_notifier.dart';
import 'package:kozuchi/features/weekly_quest/presentation/weekly_quest_app_keys.dart';
import 'package:kozuchi/features/weekly_quest/presentation/widgets/weekly_quest_section.dart';

DateTime day(int y, int m, int d) => DateTime(y, m, d);

class _StubExpenseRepository implements ExpenseRepository {
  @override
  Future<void> clearAll() async {}

  @override
  Future<void> deleteEntry(String id) async {}

  @override
  Future<List<ExpenseEntry>> getEntries({
    required DateTime start,
    required DateTime end,
  }) async =>
      const [];

  @override
  Future<int> getEntryCount() async => 0;

  @override
  Future<ExpenseEntry?> getEntryById(String id) async => null;

  @override
  Future<void> saveEntries(List<ExpenseEntry> entries) async {}

  @override
  Future<void> saveEntry(ExpenseEntry entry) async {}
}

WeeklyQuest quest(String id) => WeeklyQuest(
      id: id,
      title: '今週は食費を¥8,000以内に',
      description: '節約しよう',
      targetCategory: '食費',
      budgetLimit: 8000,
      currentAvgSpend: 10000,
      difficulty: QuestDifficulty.medium,
      generatedAt: day(2026, 10, 19),
      weekStart: day(2026, 10, 19),
      templateId: 'budgetLimit',
    );

WeeklyQuestNotifier buildNotifier(
  Future<List<WeeklyQuest>> Function(DateTime) generate,
) {
  return WeeklyQuestNotifier(
    generator: WeeklyQuestGenerator(_StubExpenseRepository()),
    store: InMemoryWeeklyQuestStore(),
    clock: () => day(2026, 10, 22),
    generateOverride: generate,
  );
}

Widget wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  testWidgets('active があるとき activeCard と達成表示が出る', (tester) async {
    final notifier = buildNotifier((_) async => [quest('q1')]);
    await notifier.ensureForWeek(entries: const []);
    await notifier.selectQuest('q1');

    await tester.pumpWidget(wrap(WeeklyQuestSection(
      notifier: notifier,
      periodOverride: WeeklyQuestPeriod.of(day(2026, 10, 22)),
    )));
    await tester.pump();

    expect(find.byKey(WeeklyQuestAppKeys.section), findsOneWidget);
    expect(find.byKey(WeeklyQuestAppKeys.activeCard), findsOneWidget);
    expect(find.byKey(WeeklyQuestAppKeys.card('q1')), findsOneWidget);
    expect(find.byKey(WeeklyQuestAppKeys.selectButton), findsNothing);
    expect(find.text('10/19(月)〜10/25(日)'), findsOneWidget);
  });

  testWidgets('pending のみのときは件数付き選択ボタンが出る', (tester) async {
    final notifier = buildNotifier((_) async => [quest('q1'), quest('q2')]);
    await notifier.ensureForWeek(entries: const []);
    var opened = 0;

    await tester.pumpWidget(wrap(WeeklyQuestSection(
      notifier: notifier,
      onOpenSelection: () => opened++,
    )));
    await tester.pump();

    expect(find.byKey(WeeklyQuestAppKeys.selectButton), findsOneWidget);
    expect(find.textContaining('候補 2件'), findsOneWidget);

    await tester.tap(find.byKey(WeeklyQuestAppKeys.selectButton));
    await tester.pump();
    expect(opened, 1);
  });

  testWidgets('候補も active も無いときは空状態', (tester) async {
    final notifier = buildNotifier((_) async => []);
    await notifier.ensureForWeek(entries: const []);

    await tester.pumpWidget(wrap(WeeklyQuestSection(notifier: notifier)));
    await tester.pump();

    expect(find.byKey(WeeklyQuestAppKeys.empty), findsOneWidget);
    expect(find.byKey(WeeklyQuestAppKeys.selectButton), findsNothing);
  });

  testWidgets('errorMessage があるときはエラー表示と再試行が動く', (tester) async {
    final notifier = buildNotifier((_) async => throw StateError('boom'));
    await notifier.ensureForWeek(entries: const []);
    var retries = 0;

    await tester.pumpWidget(wrap(WeeklyQuestSection(
      notifier: notifier,
      onRetry: () => retries++,
    )));
    await tester.pump();

    expect(find.textContaining('週次クエスト'), findsWidgets);
    expect(find.textContaining('boom'), findsOneWidget);

    await tester.tap(find.byKey(WeeklyQuestAppKeys.retryButton));
    await tester.pump();
    expect(retries, 1);
  });

  testWidgets('読み込み中はローディングインジケータ', (tester) async {
    final completer = Completer<List<WeeklyQuest>>();
    final notifier = buildNotifier((_) => completer.future);
    final future = notifier.ensureForWeek(entries: const []);

    await tester.pumpWidget(wrap(WeeklyQuestSection(notifier: notifier)));
    await tester.pump();

    expect(find.byKey(WeeklyQuestAppKeys.loading), findsOneWidget);

    completer.complete([]);
    await future;
    await tester.pump();

    expect(find.byKey(WeeklyQuestAppKeys.loading), findsNothing);
    expect(find.byKey(WeeklyQuestAppKeys.empty), findsOneWidget);
  });
}
