import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/domain/services/expense_repository.dart';
import 'package:kozuchi/features/weekly_quest/data/notifier_weekly_quest_repository.dart';
import 'package:kozuchi/features/weekly_quest/data/weekly_quest_generator.dart';
import 'package:kozuchi/features/weekly_quest/data/weekly_quest_store.dart';
import 'package:kozuchi/features/weekly_quest/domain/models/active_weekly_quest.dart';
import 'package:kozuchi/features/weekly_quest/domain/models/weekly_quest.dart';
import 'package:kozuchi/features/weekly_quest/presentation/state/weekly_quest_notifier.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WeeklyQuestNotifier notifier;
  late NotifierWeeklyQuestRepository repository;

  setUp(() async {
    notifier = WeeklyQuestNotifier(
      generator: WeeklyQuestGenerator(_StubExpenseRepository()),
      store: InMemoryWeeklyQuestStore(),
      clock: () => day(2026, 10, 22),
      generateOverride: (weekStart) async => [quest('q1'), quest('q2')],
    );
    await notifier.ensureForWeek(entries: const []);
    repository = NotifierWeeklyQuestRepository(notifier);
  });

  test('getPendingQuests は候補を pending 状態の ActiveWeeklyQuest に包む', () async {
    final pending = await repository.getPendingQuests('local');

    expect(pending.length, 2);
    expect(pending.map((e) => e.quest.id), ['q1', 'q2']);
    expect(pending.every((e) => e.status == WeeklyQuestStatus.pending), isTrue);
    expect(pending.first.quest, notifier.pendingQuests.first);
  });

  test('selectQuest は notifier の選択処理に到達する', () async {
    await repository.selectQuest('local', 'q2');

    expect(notifier.activeQuest?.quest.id, 'q2');
    expect(notifier.pendingQuests.map((q) => q.id), ['q1']);
  });

  test('getActiveQuest は notifier の active を返す', () async {
    expect(await repository.getActiveQuest('local'), isNull);

    await repository.selectQuest('local', 'q1');

    final active = await repository.getActiveQuest('local');
    expect(active, isNotNull);
    expect(active!.quest.id, 'q1');
    expect(active.status, WeeklyQuestStatus.active);
  });
}
