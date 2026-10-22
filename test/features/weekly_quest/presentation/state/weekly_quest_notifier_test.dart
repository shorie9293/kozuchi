import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/domain/services/expense_repository.dart';
import 'package:kozuchi/features/weekly_quest/data/weekly_quest_generator.dart';
import 'package:kozuchi/features/weekly_quest/data/weekly_quest_store.dart';
import 'package:kozuchi/features/weekly_quest/domain/models/active_weekly_quest.dart';
import 'package:kozuchi/features/weekly_quest/domain/models/weekly_quest.dart';
import 'package:kozuchi/features/weekly_quest/domain/models/weekly_quest_state.dart';
import 'package:kozuchi/features/weekly_quest/presentation/state/weekly_quest_notifier.dart';

DateTime day(int year, int month, int dayOfMonth) =>
    DateTime(year, month, dayOfMonth);

/// generate() を呼ばせないためのダミーリポジトリ
/// （実際の生成は generateOverride で差し替える）。
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

/// 生成回数を数えるフェイク。呼ばれた weekStart も記録する。
class CountingGenerator {
  CountingGenerator({this.quests, this.error});

  final List<WeeklyQuest>? quests;
  final Object? error;
  int calls = 0;
  DateTime? lastWeekStart;

  Future<List<WeeklyQuest>> call(DateTime weekStart) async {
    calls++;
    lastWeekStart = weekStart;
    final failure = error;
    if (failure != null) throw failure;
    return quests ?? [quest(id: 'q1'), quest(id: 'q2')];
  }
}

WeeklyQuest quest({String id = 'q1', String targetCategory = '食費'}) {
  return WeeklyQuest(
    id: id,
    title: '今週は$targetCategoryを¥8,000以内に',
    description: '節約しよう',
    targetCategory: targetCategory,
    budgetLimit: 8000,
    currentAvgSpend: 10000,
    difficulty: QuestDifficulty.medium,
    generatedAt: day(2026, 10, 19),
    weekStart: day(2026, 10, 19),
    templateId: 'budgetLimit',
  );
}

WeeklyQuestNotifier buildNotifier({
  required CountingGenerator fake,
  required WeeklyQuestStore store,
  DateTime? clockValue,
}) {
  return WeeklyQuestNotifier(
    generator: WeeklyQuestGenerator(_StubExpenseRepository()),
    store: store,
    clock: clockValue == null ? () => day(2026, 10, 21) : () => clockValue,
    generateOverride: fake.call,
  );
}

void main() {
  group('ensureForWeek', () {
    test('未保存なら生成して保存する', () async {
      final fake = CountingGenerator();
      final store = InMemoryWeeklyQuestStore();
      final notifier = buildNotifier(fake: fake, store: store);

      await notifier.ensureForWeek(entries: const [], now: day(2026, 10, 21));

      expect(fake.calls, 1);
      expect(fake.lastWeekStart, day(2026, 10, 19));
      expect(notifier.state?.weekKey, '2026-10-19');
      expect(notifier.pendingQuests.map((q) => q.id), ['q1', 'q2']);
      expect(notifier.activeQuest, isNull);
      expect(store.stored, notifier.state);
      expect(notifier.isLoading, isFalse);
      expect(notifier.errorMessage, isNull);
    });

    test('同一週の2回目は再生成しない', () async {
      final fake = CountingGenerator();
      final store = InMemoryWeeklyQuestStore();
      final notifier = buildNotifier(fake: fake, store: store);

      await notifier.ensureForWeek(entries: const [], now: day(2026, 10, 19));
      await notifier.ensureForWeek(entries: const [], now: day(2026, 10, 25));

      expect(fake.calls, 1);
      expect(notifier.pendingQuests.length, 2);
    });

    test('週が変われば再生成する', () async {
      final fake = CountingGenerator();
      final store = InMemoryWeeklyQuestStore();
      final notifier = buildNotifier(fake: fake, store: store);

      await notifier.ensureForWeek(entries: const [], now: day(2026, 10, 21));
      await notifier.ensureForWeek(entries: const [], now: day(2026, 10, 28));

      expect(fake.calls, 2);
      expect(fake.lastWeekStart, day(2026, 10, 26));
      expect(notifier.state?.weekKey, '2026-10-26');
      expect(store.stored?.weekKey, '2026-10-26');
    });

    test('生成が空リストでも例外にせず保存する', () async {
      final fake = CountingGenerator(quests: const []);
      final store = InMemoryWeeklyQuestStore();
      final notifier = buildNotifier(fake: fake, store: store);

      await notifier.ensureForWeek(entries: const [], now: day(2026, 10, 21));

      expect(notifier.errorMessage, isNull);
      expect(notifier.pendingQuests, isEmpty);
      expect(notifier.state?.isEmpty, isTrue);
      expect(store.stored, isNotNull);
      expect(store.stored?.isEmpty, isTrue);
    });

    test('生成が例外を投げたら errorMessage に載せ、状態は落とさない', () async {
      final fake = CountingGenerator(error: StateError('生成失敗'));
      final store = InMemoryWeeklyQuestStore();
      final notifier = buildNotifier(fake: fake, store: store);

      await notifier.ensureForWeek(entries: const [], now: day(2026, 10, 21));

      expect(notifier.errorMessage, isNotNull);
      expect(notifier.errorMessage, contains('生成失敗'));
      expect(notifier.isLoading, isFalse);
      expect(notifier.state, isNull);
      expect(store.stored, isNull);
    });

    test('isLoading が true→false と遷移する', () async {
      final fake = CountingGenerator();
      final store = InMemoryWeeklyQuestStore();
      final notifier = buildNotifier(fake: fake, store: store);
      final history = <bool>[];
      notifier.addListener(() => history.add(notifier.isLoading));

      await notifier.ensureForWeek(entries: const [], now: day(2026, 10, 21));

      expect(history.first, isTrue);
      expect(history.last, isFalse);
      expect(notifier.isLoading, isFalse);
    });

    test('保存済み state をそのまま採用する（active も保つ）', () async {
      final fake = CountingGenerator();
      final store = InMemoryWeeklyQuestStore();
      await store.save(
        WeeklyQuestState(
          weekKey: '2026-10-19',
          pending: const [],
          active: ActiveWeeklyQuest(
            quest: quest(id: 'saved'),
            status: WeeklyQuestStatus.active,
            selectedAt: day(2026, 10, 20),
          ),
          generatedAt: day(2026, 10, 19),
        ),
      );
      final notifier = buildNotifier(fake: fake, store: store);

      await notifier.ensureForWeek(entries: const [], now: day(2026, 10, 21));

      expect(fake.calls, 0);
      expect(notifier.activeQuest?.quest.id, 'saved');
      expect(notifier.pendingQuests, isEmpty);
    });
  });

  group('selectQuest', () {
    test('pending から active へ移し、store に反映する', () async {
      final fake = CountingGenerator();
      final store = InMemoryWeeklyQuestStore();
      final notifier = buildNotifier(fake: fake, store: store);
      await notifier.ensureForWeek(entries: const [], now: day(2026, 10, 21));

      await notifier.selectQuest('q1', now: day(2026, 10, 21));

      expect(notifier.activeQuest?.quest.id, 'q1');
      expect(notifier.activeQuest?.status, WeeklyQuestStatus.active);
      expect(notifier.activeQuest?.selectedAt, day(2026, 10, 21));
      expect(notifier.pendingQuests.map((q) => q.id), ['q2']);
      expect(store.stored?.active?.quest.id, 'q1');
      expect(store.stored?.pending.map((q) => q.id), ['q2']);
    });

    test('未知の ID は何も変えない', () async {
      final fake = CountingGenerator();
      final store = InMemoryWeeklyQuestStore();
      final notifier = buildNotifier(fake: fake, store: store);
      await notifier.ensureForWeek(entries: const [], now: day(2026, 10, 21));
      final before = notifier.state;

      await notifier.selectQuest('does-not-exist');

      expect(notifier.state, before);
      expect(notifier.activeQuest, isNull);
      expect(notifier.pendingQuests.length, 2);
      expect(store.stored, before);
    });

    test('state が未ロードなら何もしない（例外なし）', () async {
      final fake = CountingGenerator();
      final store = InMemoryWeeklyQuestStore();
      final notifier = buildNotifier(fake: fake, store: store);

      await notifier.selectQuest('q1');

      expect(notifier.state, isNull);
      expect(store.stored, isNull);
    });

    test('選択後に ensureForWeek しても同一週なら選択が保たれる', () async {
      final fake = CountingGenerator();
      final store = InMemoryWeeklyQuestStore();
      final notifier = buildNotifier(fake: fake, store: store);
      await notifier.ensureForWeek(entries: const [], now: day(2026, 10, 21));
      await notifier.selectQuest('q1', now: day(2026, 10, 21));

      await notifier.ensureForWeek(entries: const [], now: day(2026, 10, 22));

      expect(fake.calls, 1);
      expect(notifier.activeQuest?.quest.id, 'q1');
    });
  });

  group('activeProgress', () {
    test('未選択なら null', () async {
      final fake = CountingGenerator();
      final notifier = buildNotifier(
        fake: fake,
        store: InMemoryWeeklyQuestStore(),
      );
      await notifier.ensureForWeek(entries: const [], now: day(2026, 10, 21));
      expect(notifier.activeProgress, isNull);
    });

    test('選択後は支出を集計した進捗を返す', () async {
      final fake = CountingGenerator();
      final notifier = buildNotifier(
        fake: fake,
        store: InMemoryWeeklyQuestStore(),
        clockValue: day(2026, 10, 21),
      );
      final entries = [
        ExpenseEntry(
          id: 'e1',
          amount: 3000,
          category: '食費',
          date: day(2026, 10, 20),
        ),
      ];
      await notifier.ensureForWeek(entries: entries, now: day(2026, 10, 21));
      await notifier.selectQuest('q1', now: day(2026, 10, 21));

      final progress = notifier.activeProgress;
      expect(progress, isNotNull);
      expect(progress!.spentAmount, 3000);
      expect(progress.status, WeeklyQuestStatus.active);
      expect(progress.remainingAmount, 5000);
      expect(progress.remainingDays, 5);
      expect(progress.hasEnded, isFalse);
    });

    test('週外の支出は進捗に含めない', () async {
      final fake = CountingGenerator();
      final notifier = buildNotifier(
        fake: fake,
        store: InMemoryWeeklyQuestStore(),
        clockValue: day(2026, 10, 21),
      );
      final entries = [
        ExpenseEntry(
          id: 'e1',
          amount: 9999,
          category: '食費',
          date: day(2026, 10, 12),
        ),
      ];
      await notifier.ensureForWeek(entries: entries, now: day(2026, 10, 21));
      await notifier.selectQuest('q1', now: day(2026, 10, 21));

      expect(notifier.activeProgress?.spentAmount, 0);
    });
  });

  group('reload', () {
    test('保存済みでも再生成し、active を捨てる', () async {
      final fake = CountingGenerator();
      final store = InMemoryWeeklyQuestStore();
      final notifier = buildNotifier(fake: fake, store: store);
      await notifier.ensureForWeek(entries: const [], now: day(2026, 10, 21));
      await notifier.selectQuest('q1', now: day(2026, 10, 21));

      await notifier.reload(entries: const [], now: day(2026, 10, 22));

      expect(fake.calls, 2);
      expect(notifier.activeQuest, isNull);
      expect(notifier.pendingQuests.length, 2);
      expect(store.stored?.active, isNull);
      expect(notifier.isLoading, isFalse);
    });

    test('例外時は errorMessage に載せる', () async {
      final fake = CountingGenerator(error: StateError('再生成失敗'));
      final notifier = buildNotifier(
        fake: fake,
        store: InMemoryWeeklyQuestStore(),
      );

      await notifier.reload(entries: const [], now: day(2026, 10, 21));

      expect(notifier.errorMessage, contains('再生成失敗'));
      expect(notifier.isLoading, isFalse);
    });
  });
}
