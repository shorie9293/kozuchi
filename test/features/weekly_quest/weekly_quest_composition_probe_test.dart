// 親探針（イシコリドメ）: 週次クエストの合成不変条件を撃つ。
//
// 眷属の試練は各層を個別に検証しがちなので、ここでは
//   ① 生成→選択→永続化→別インスタンスでの復元（保存到達の検証）
//   ② 画面の表示がサービス出力と完全一致すること（独自集計の検出）
//   ③ 上限超過が週の途中でも即「超過」になること
//   ④ 週が変われば再生成されること
//   ⑤ 未知IDで状態が変わらないこと
// を実データで撃つ。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/domain/services/expense_repository.dart';
import 'package:kozuchi/features/weekly_quest/data/weekly_quest_generator.dart';
import 'package:kozuchi/features/weekly_quest/data/weekly_quest_store.dart';
import 'package:kozuchi/features/weekly_quest/domain/models/active_weekly_quest.dart';
import 'package:kozuchi/features/weekly_quest/domain/models/weekly_quest.dart';
import 'package:kozuchi/features/weekly_quest/domain/weekly_quest_period.dart';
import 'package:kozuchi/features/weekly_quest/domain/weekly_quest_progress.dart';
import 'package:kozuchi/features/weekly_quest/presentation/state/weekly_quest_notifier.dart';
import 'package:kozuchi/features/weekly_quest/presentation/weekly_quest_app_keys.dart';
import 'package:kozuchi/features/weekly_quest/presentation/widgets/weekly_quest_section.dart';

final _monday = DateTime(2026, 10, 19); // 月曜
final _now = DateTime(2026, 10, 22, 12); // 木曜

/// 生成器の依存解決用（generateOverride があるので実際には呼ばれない）。
class _NoopExpenseRepository implements ExpenseRepository {
  const _NoopExpenseRepository();

  @override
  Future<List<ExpenseEntry>> getEntries({
    required DateTime start,
    required DateTime end,
  }) async =>
      const [];

  @override
  Future<void> saveEntry(ExpenseEntry entry) async {}

  @override
  Future<void> saveEntries(List<ExpenseEntry> entries) async {}

  @override
  Future<int> getEntryCount() async => 0;

  @override
  Future<void> clearAll() async {}

  @override
  Future<void> deleteEntry(String id) async {}

  @override
  Future<ExpenseEntry?> getEntryById(String id) async => null;
}

WeeklyQuest _quest(String id, {int limit = 10000, String category = '食費'}) {
  return WeeklyQuest(
    id: id,
    title: '$categoryを¥$limit以内に',
    description: '説明',
    targetCategory: category,
    budgetLimit: limit,
    currentAvgSpend: 12000,
    difficulty: QuestDifficulty.medium,
    generatedAt: _monday,
    weekStart: _monday,
    templateId: 'budgetLimit',
  );
}

WeeklyQuestNotifier _notifier({
  WeeklyQuestStore? store,
  int Function()? onGenerate,
  DateTime Function()? clock,
}) {
  final quests = [_quest('q1'), _quest('q2', limit: 5000)];
  return WeeklyQuestNotifier(
    generator: WeeklyQuestGenerator(const _NoopExpenseRepository()),
    store: store ?? InMemoryWeeklyQuestStore(),
    clock: clock ?? () => _now,
    generateOverride: (weekStart) async {
      onGenerate?.call();
      return quests;
    },
  );
}

Future<void> _pumpSection(
  WidgetTester tester,
  WeeklyQuestNotifier notifier,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: WeeklyQuestSection(
            notifier: notifier,
            periodOverride: WeeklyQuestPeriod.of(_now),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('① 候補件数ボタン→選択→別インスタンスで復元（永続化到達の合成）',
      (tester) async {
    final store = InMemoryWeeklyQuestStore();
    final a = _notifier(store: store);
    await a.ensureForWeek(entries: const [], now: _now);

    await _pumpSection(tester, a);
    expect(find.byKey(WeeklyQuestAppKeys.selectButton), findsOneWidget);
    expect(
      find.textContaining('候補 ${a.pendingQuests.length}件'),
      findsOneWidget,
    );
    expect(find.byKey(WeeklyQuestAppKeys.activeCard), findsNothing);

    await a.selectQuest('q1', now: _now);
    expect(store.stored?.active?.quest.id, 'q1');
    expect(store.stored!.pending.length, 1);

    // 再起動相当: 同じ store から別インスタンスで復元
    final b = _notifier(store: store);
    await b.ensureForWeek(entries: const [], now: _now);
    expect(b.activeQuest?.quest.id, 'q1');

    await _pumpSection(tester, b);
    expect(find.byKey(WeeklyQuestAppKeys.activeCard), findsOneWidget);
  });

  testWidgets('② 画面の表示はサービス出力と完全一致（独自集計の検出）',
      (tester) async {
    final notifier = _notifier();
    await notifier.ensureForWeek(entries: const [], now: _now);
    await notifier.selectQuest('q1', now: _now);

    final entries = [
      ExpenseEntry(
        id: 'e1',
        amount: 4000,
        category: '食費',
        date: DateTime(2026, 10, 20),
      ),
      ExpenseEntry(
        id: 'e2',
        amount: 2000,
        category: '食費',
        date: DateTime(2026, 10, 21),
      ),
      // 週外は集計に入らない
      ExpenseEntry(
        id: 'e3',
        amount: 9000,
        category: '食費',
        date: DateTime(2026, 10, 12),
      ),
      // 別カテゴリは集計に入らない
      ExpenseEntry(
        id: 'e4',
        amount: 9000,
        category: '娯楽',
        date: DateTime(2026, 10, 21),
      ),
    ];
    await notifier.ensureForWeek(entries: entries, now: _now);

    final expected = const WeeklyQuestProgressService().evaluate(
      quest: _quest('q1'),
      entries: entries,
      period: WeeklyQuestPeriod.of(_now),
      now: _now,
      baseStatus: WeeklyQuestStatus.active,
    );
    expect(expected.spentAmount, 6000);
    expect(expected.ratio, closeTo(0.6, 1e-9));
    expect(notifier.activeProgress!.spentAmount, expected.spentAmount);
    expect(notifier.activeProgress!.summaryLabel, expected.summaryLabel);

    await _pumpSection(tester, notifier);
    expect(find.text(expected.spentLabel), findsOneWidget);
    expect(find.text(expected.summaryLabel), findsOneWidget);
    expect(find.text(expected.statusLabel), findsOneWidget);
  });

  testWidgets('③ 上限超過は週の途中でも即「超過」表示', (tester) async {
    final notifier = _notifier();
    await notifier.ensureForWeek(entries: const [], now: _now);
    await notifier.selectQuest('q1', now: _now);

    await notifier.ensureForWeek(
      entries: [
        ExpenseEntry(
          id: 'over',
          amount: 12000,
          category: '食費',
          date: DateTime(2026, 10, 21),
        ),
      ],
      now: _now,
    );
    await _pumpSection(tester, notifier);

    expect(notifier.activeProgress!.status, WeeklyQuestStatus.failed);
    expect(find.text('超過'), findsOneWidget);
    expect(notifier.activeProgress!.ratio, 1.0);
  });

  test('④ 週が変われば再生成され、同一週では再生成されない', () async {
    var calls = 0;
    final store = InMemoryWeeklyQuestStore();
    final notifier = _notifier(store: store, onGenerate: () => ++calls);

    await notifier.ensureForWeek(entries: const [], now: _now);
    expect(calls, 1);
    await notifier.ensureForWeek(entries: const [], now: _now);
    expect(calls, 1, reason: '同一週は保存済みを再利用する');

    await notifier.ensureForWeek(
      entries: const [],
      now: DateTime(2026, 10, 26, 9), // 翌週月曜
    );
    expect(calls, 2);
    expect(store.stored!.weekKey, '2026-10-26');
  });

  test('⑤ 未知の questId は状態を変えない（例外も投げない）', () async {
    final store = InMemoryWeeklyQuestStore();
    final notifier = _notifier(store: store);
    await notifier.ensureForWeek(entries: const [], now: _now);
    final before = store.stored!;

    await notifier.selectQuest('does-not-exist', now: _now);

    expect(notifier.activeQuest, isNull);
    expect(store.stored!.pending.length, before.pending.length);
  });
}
