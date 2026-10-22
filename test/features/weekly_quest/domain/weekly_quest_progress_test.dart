import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/features/weekly_quest/domain/models/active_weekly_quest.dart';
import 'package:kozuchi/features/weekly_quest/domain/models/weekly_quest.dart';
import 'package:kozuchi/features/weekly_quest/domain/weekly_quest_period.dart';
import 'package:kozuchi/features/weekly_quest/domain/weekly_quest_progress.dart';

DateTime day(int year, int month, int dayOfMonth) =>
    DateTime(year, month, dayOfMonth);

WeeklyQuest quest({
  String id = 'q1',
  String targetCategory = '食費',
  int budgetLimit = 10000,
}) {
  return WeeklyQuest(
    id: id,
    title: '今週は$targetCategoryを¥$budgetLimit以内に',
    description: '節約しよう',
    targetCategory: targetCategory,
    budgetLimit: budgetLimit,
    currentAvgSpend: 12000,
    difficulty: QuestDifficulty.medium,
    generatedAt: day(2026, 10, 19),
    weekStart: day(2026, 10, 19),
    templateId: 'budgetLimit',
  );
}

ExpenseEntry entry({
  required String id,
  required int amount,
  required String category,
  required DateTime date,
}) {
  return ExpenseEntry(
    id: id,
    amount: amount,
    category: category,
    date: date,
  );
}

void main() {
  const service = WeeklyQuestProgressService();
  final period = WeeklyQuestPeriod(weekStart: day(2026, 10, 19));
  final now = day(2026, 10, 21); // 水曜・週の途中

  group('spentFor: 集計規則', () {
    test('カテゴリは完全一致のみ合算する', () {
      final entries = [
        entry(id: 'e1', amount: 3000, category: '食費', date: day(2026, 10, 19)),
        entry(id: 'e2', amount: 2000, category: '食費', date: day(2026, 10, 22)),
        entry(id: 'e3', amount: 9000, category: '娯楽', date: day(2026, 10, 20)),
        // 部分一致・別表記は対象外（正規化しない）
        entry(id: 'e4', amount: 5000, category: '食費（外食）', date: day(2026, 10, 20)),
      ];
      final spent = service.spentFor(
        quest: quest(targetCategory: '食費'),
        entries: entries,
        period: period,
      );
      expect(spent, 5000);
    });

    test('総支出は全カテゴリを合算する', () {
      final entries = [
        entry(id: 'e1', amount: 3000, category: '食費', date: day(2026, 10, 19)),
        entry(id: 'e2', amount: 9000, category: '娯楽', date: day(2026, 10, 20)),
        entry(id: 'e3', amount: 1000, category: '交通費', date: day(2026, 10, 25)),
      ];
      final spent = service.spentFor(
        quest: quest(targetCategory: '総支出'),
        entries: entries,
        period: period,
      );
      expect(spent, 13000);
    });

    test('週外のエントリは除外する（開始前・終端以降）', () {
      final entries = [
        entry(id: 'e1', amount: 3000, category: '食費', date: day(2026, 10, 18)),
        entry(id: 'e2', amount: 2000, category: '食費', date: day(2026, 10, 19)),
        entry(id: 'e3', amount: 7000, category: '食費', date: day(2026, 10, 26)),
      ];
      final spent = service.spentFor(
        quest: quest(targetCategory: '食費'),
        entries: entries,
        period: period,
      );
      expect(spent, 2000);
    });

    test('該当なしは 0', () {
      final spent = service.spentFor(
        quest: quest(targetCategory: '医療費'),
        entries: [
          entry(id: 'e1', amount: 3000, category: '食費', date: day(2026, 10, 19)),
        ],
        period: period,
      );
      expect(spent, 0);
    });

    test('amount は常に正（0以下はモデルの assert で生成不能）', () {
      // ExpenseEntry は assert(amount > 0) を持つため、0円・負額の
      // エントリはそもそも存在し得ない。集計側の `amount > 0` ガードは
      // 防御的措置であり、ここではモデルの不変条件を確認する。
      expect(
        () => entry(id: 'bad', amount: 0, category: '食費', date: day(2026, 10, 19)),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('WeeklyQuestProgress: 派生値', () {
    test('ratio は 0.0..1.0 にクランプされる', () {
      final zero = WeeklyQuestProgress(
        quest: quest(budgetLimit: 10000),
        spentAmount: 0,
        remainingDays: 7,
        hasEnded: false,
        status: WeeklyQuestStatus.active,
      );
      expect(zero.ratio, 0.0);

      final half = WeeklyQuestProgress(
        quest: quest(budgetLimit: 10000),
        spentAmount: 5000,
        remainingDays: 4,
        hasEnded: false,
        status: WeeklyQuestStatus.active,
      );
      expect(half.ratio, 0.5);

      final over = WeeklyQuestProgress(
        quest: quest(budgetLimit: 10000),
        spentAmount: 18000,
        remainingDays: 2,
        hasEnded: false,
        status: WeeklyQuestStatus.failed,
      );
      expect(over.ratio, 1.0);
    });

    test('remainingAmount は負にならない', () {
      final within = WeeklyQuestProgress(
        quest: quest(budgetLimit: 10000),
        spentAmount: 8000,
        remainingDays: 3,
        hasEnded: false,
        status: WeeklyQuestStatus.active,
      );
      expect(within.remainingAmount, 2000);
      expect(within.isWithinBudget, isTrue);

      final over = WeeklyQuestProgress(
        quest: quest(budgetLimit: 10000),
        spentAmount: 12000,
        remainingDays: 3,
        hasEnded: false,
        status: WeeklyQuestStatus.failed,
      );
      expect(over.remainingAmount, 0);
      expect(over.isWithinBudget, isFalse);
    });

    test('ちょうど予算は予算内', () {
      final exact = WeeklyQuestProgress(
        quest: quest(budgetLimit: 10000),
        spentAmount: 10000,
        remainingDays: 1,
        hasEnded: false,
        status: WeeklyQuestStatus.active,
      );
      expect(exact.isWithinBudget, isTrue);
      expect(exact.remainingAmount, 0);
    });

    test('spentLabel は3桁カンマ区切り', () {
      final progress = WeeklyQuestProgress(
        quest: quest(budgetLimit: 10000),
        spentAmount: 8000,
        remainingDays: 3,
        hasEnded: false,
        status: WeeklyQuestStatus.active,
      );
      expect(progress.spentLabel, '¥8,000 / ¥10,000');
    });

    test('formatYen は桁区切りを自前で行う', () {
      expect(WeeklyQuestProgress.formatYen(0), '¥0');
      expect(WeeklyQuestProgress.formatYen(999), '¥999');
      expect(WeeklyQuestProgress.formatYen(1000), '¥1,000');
      expect(WeeklyQuestProgress.formatYen(1234567), '¥1,234,567');
    });

    test('statusLabel は 4状態を日本語化する', () {
      String labelOf(WeeklyQuestStatus status) => WeeklyQuestProgress(
            quest: quest(),
            spentAmount: 0,
            remainingDays: 7,
            hasEnded: false,
            status: status,
          ).statusLabel;

      expect(labelOf(WeeklyQuestStatus.pending), '選択待ち');
      expect(labelOf(WeeklyQuestStatus.active), '挑戦中');
      expect(labelOf(WeeklyQuestStatus.completed), '達成！');
      expect(labelOf(WeeklyQuestStatus.failed), '超過');
    });

    test('summaryLabel: 予算内で継続中', () {
      final progress = WeeklyQuestProgress(
        quest: quest(budgetLimit: 10000),
        spentAmount: 8000,
        remainingDays: 3,
        hasEnded: false,
        status: WeeklyQuestStatus.active,
      );
      expect(progress.summaryLabel, '残り¥2,000・あと3日');
    });

    test('summaryLabel: 予算超過', () {
      final progress = WeeklyQuestProgress(
        quest: quest(budgetLimit: 10000),
        spentAmount: 12500,
        remainingDays: 3,
        hasEnded: false,
        status: WeeklyQuestStatus.failed,
      );
      expect(progress.summaryLabel, '¥2,500 超過');
    });

    test('summaryLabel: 週終了かつ予算内', () {
      final progress = WeeklyQuestProgress(
        quest: quest(budgetLimit: 10000),
        spentAmount: 7500,
        remainingDays: 0,
        hasEnded: true,
        status: WeeklyQuestStatus.completed,
      );
      expect(progress.summaryLabel, '達成！¥2,500 の余裕');
    });

    test('等価性は全フィールドで判定する', () {
      final a = WeeklyQuestProgress(
        quest: quest(),
        spentAmount: 100,
        remainingDays: 1,
        hasEnded: false,
        status: WeeklyQuestStatus.active,
      );
      final b = WeeklyQuestProgress(
        quest: quest(),
        spentAmount: 100,
        remainingDays: 1,
        hasEnded: false,
        status: WeeklyQuestStatus.active,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);

      final c = WeeklyQuestProgress(
        quest: quest(),
        spentAmount: 200,
        remainingDays: 1,
        hasEnded: false,
        status: WeeklyQuestStatus.active,
      );
      expect(a == c, isFalse);
    });
  });

  group('evaluate: 判定順序（pending→failed→completed→active）', () {
    test('baseStatus が pending なら常に pending（超過していても）', () {
      final progress = service.evaluate(
        quest: quest(budgetLimit: 1000),
        entries: [
          entry(id: 'e1', amount: 9000, category: '食費', date: day(2026, 10, 20)),
        ],
        period: period,
        now: day(2026, 10, 26), // 週終了後でも
        baseStatus: WeeklyQuestStatus.pending,
      );
      expect(progress.status, WeeklyQuestStatus.pending);
    });

    test('予算超過は週の途中でも即 failed', () {
      final progress = service.evaluate(
        quest: quest(budgetLimit: 10000),
        entries: [
          entry(id: 'e1', amount: 8000, category: '食費', date: day(2026, 10, 20)),
          entry(id: 'e2', amount: 3000, category: '食費', date: day(2026, 10, 21)),
        ],
        period: period,
        now: now,
      );
      expect(progress.status, WeeklyQuestStatus.failed);
      expect(progress.hasEnded, isFalse);
      expect(progress.spentAmount, 11000);
    });

    test('週終了かつ予算内は completed', () {
      final progress = service.evaluate(
        quest: quest(budgetLimit: 10000),
        entries: [
          entry(id: 'e1', amount: 4000, category: '食費', date: day(2026, 10, 20)),
        ],
        period: period,
        now: day(2026, 10, 26),
      );
      expect(progress.status, WeeklyQuestStatus.completed);
      expect(progress.hasEnded, isTrue);
      expect(progress.remainingDays, 0);
    });

    test('週終了かつ予算超過は failed（completed より優先）', () {
      final progress = service.evaluate(
        quest: quest(budgetLimit: 10000),
        entries: [
          entry(id: 'e1', amount: 15000, category: '食費', date: day(2026, 10, 20)),
        ],
        period: period,
        now: day(2026, 10, 26),
      );
      expect(progress.status, WeeklyQuestStatus.failed);
    });

    test('週の途中で予算内は active', () {
      final progress = service.evaluate(
        quest: quest(budgetLimit: 10000),
        entries: [
          entry(id: 'e1', amount: 3000, category: '食費', date: day(2026, 10, 20)),
        ],
        period: period,
        now: now,
      );
      expect(progress.status, WeeklyQuestStatus.active);
      expect(progress.spentAmount, 3000);
      expect(progress.remainingDays, 5);
    });
  });

  group('evaluateAll', () {
    test('入力順を保って全件評価する', () {
      final quests = [
        quest(id: 'a', targetCategory: '食費', budgetLimit: 5000),
        quest(id: 'b', targetCategory: '総支出', budgetLimit: 20000),
        quest(id: 'c', targetCategory: '娯楽', budgetLimit: 1000),
      ];
      final entries = [
        entry(id: 'e1', amount: 6000, category: '食費', date: day(2026, 10, 20)),
        entry(id: 'e2', amount: 2000, category: '娯楽', date: day(2026, 10, 21)),
      ];
      final results = service.evaluateAll(
        quests: quests,
        entries: entries,
        period: period,
        now: now,
      );
      expect(results.map((r) => r.quest.id), ['a', 'b', 'c']);
      expect(results[0].spentAmount, 6000);
      expect(results[0].status, WeeklyQuestStatus.failed);
      expect(results[1].spentAmount, 8000);
      expect(results[1].status, WeeklyQuestStatus.active);
      expect(results[2].status, WeeklyQuestStatus.failed);
    });

    test('空リストは空リストを返す', () {
      final results = service.evaluateAll(
        quests: const [],
        entries: const [],
        period: period,
        now: now,
      );
      expect(results, isEmpty);
    });
  });
}
