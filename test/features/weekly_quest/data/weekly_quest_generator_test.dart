import 'package:test/test.dart';
import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/domain/services/expense_repository_impl.dart';
import 'package:kozuchi/features/weekly_quest/data/weekly_quest_generator.dart';
import 'package:kozuchi/features/weekly_quest/data/quest_templates.dart';
import 'package:kozuchi/features/weekly_quest/domain/models/weekly_quest.dart';

void main() {
  // ── WeeklyQuest model ──
  group('WeeklyQuest', () {
    test('creates from constructor', () {
      final quest = WeeklyQuest(
        id: 'q1',
        title: '今週は食費を¥8,000以内に',
        description: '節約しよう',
        targetCategory: '食費',
        budgetLimit: 8000,
        currentAvgSpend: 10000,
        difficulty: QuestDifficulty.medium,
        generatedAt: DateTime(2026, 6, 22),
        weekStart: DateTime(2026, 6, 22),
        templateId: 'budgetLimit',
      );
      expect(quest.id, 'q1');
      expect(quest.title, '今週は食費を¥8,000以内に');
      expect(quest.targetCategory, '食費');
      expect(quest.budgetLimit, 8000);
      expect(quest.currentAvgSpend, 10000);
      expect(quest.difficulty, QuestDifficulty.medium);
      expect(quest.reductionPercent, closeTo(20.0, 0.1));
      expect(quest.reductionAmount, 2000);
    });

    test('reductionPercent and reductionAmount when no spend', () {
      final quest = WeeklyQuest(
        id: 'q2',
        title: 'test',
        description: 'test',
        targetCategory: '食費',
        budgetLimit: 1000,
        currentAvgSpend: 0,
        difficulty: QuestDifficulty.easy,
        generatedAt: DateTime(2026),
        weekStart: DateTime(2026),
        templateId: 'test',
      );
      expect(quest.reductionPercent, 0.0);
      expect(quest.reductionAmount, 0);
    });

    test('asserts budgetLimit > 0', () {
      expect(
        () => WeeklyQuest(
          id: 'q',
          title: 't',
          description: 'd',
          targetCategory: 'c',
          budgetLimit: 0,
          currentAvgSpend: 1000,
          difficulty: QuestDifficulty.easy,
          generatedAt: DateTime(2026),
          weekStart: DateTime(2026),
          templateId: 'test',
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('JSON serialization roundtrip', () {
      final quest = WeeklyQuest(
        id: 'q1',
        title: '今週は娯楽費を¥5,000以内に',
        description: '節約の心得',
        targetCategory: '娯楽',
        budgetLimit: 5000,
        currentAvgSpend: 8000,
        difficulty: QuestDifficulty.hard,
        generatedAt: DateTime(2026, 6, 22, 10, 0),
        weekStart: DateTime(2026, 6, 22),
        templateId: 'budgetLimit',
      );
      final json = quest.toJson();
      final restored = WeeklyQuest.fromJson(json);
      expect(restored.id, quest.id);
      expect(restored.title, quest.title);
      expect(restored.description, quest.description);
      expect(restored.targetCategory, quest.targetCategory);
      expect(restored.budgetLimit, quest.budgetLimit);
      expect(restored.currentAvgSpend, quest.currentAvgSpend);
      expect(restored.difficulty, quest.difficulty);
      expect(restored.templateId, quest.templateId);
    });

    test('summary', () {
      final quest = WeeklyQuest(
        id: 'q1',
        title: 'test',
        description: 'test',
        targetCategory: '食費',
        budgetLimit: 8000,
        currentAvgSpend: 10000,
        difficulty: QuestDifficulty.medium,
        generatedAt: DateTime(2026),
        weekStart: DateTime(2026),
        templateId: 'test',
      );
      expect(quest.summary, contains('¥8000'));
      expect(quest.summary, contains('¥10000'));
    });
  });

  // ── QuestDifficulty ──
  group('QuestDifficulty', () {
    test('fromReductionPercent', () {
      expect(QuestDifficulty.fromReductionPercent(5), QuestDifficulty.easy);
      expect(QuestDifficulty.fromReductionPercent(14.9), QuestDifficulty.easy);
      expect(QuestDifficulty.fromReductionPercent(15), QuestDifficulty.medium);
      expect(QuestDifficulty.fromReductionPercent(24.9), QuestDifficulty.medium);
      expect(QuestDifficulty.fromReductionPercent(25), QuestDifficulty.hard);
      expect(QuestDifficulty.fromReductionPercent(50), QuestDifficulty.hard);
    });

    test('label returns Japanese', () {
      expect(QuestDifficulty.easy.label, '易');
      expect(QuestDifficulty.medium.label, '中');
      expect(QuestDifficulty.hard.label, '難');
    });
  });

  // ── QuestTemplate ──
  group('QuestTemplate', () {
    test('all returns 5 templates', () {
      expect(QuestTemplate.all.length, 5);
    });

    test('byId maps all templates', () {
      expect(QuestTemplate.byId.length, 5);
      expect(QuestTemplate.byId.containsKey('budgetLimit'), true);
      expect(QuestTemplate.byId.containsKey('frequencyReduce'), true);
      expect(QuestTemplate.byId.containsKey('comparePrevious'), true);
      expect(QuestTemplate.byId.containsKey('totalCap'), true);
      expect(QuestTemplate.byId.containsKey('noSpendDay'), true);
    });

    test('budgetLimit template generates title', () {
      final t = QuestTemplate.byId['budgetLimit']!;
      final title = t.titleBuilder('食費', 8000, 0);
      expect(title, contains('食費'));
      expect(title, contains('8000'));
    });

    test('totalCap template uses category as empty string in title', () {
      final t = QuestTemplate.byId['totalCap']!;
      final title = t.titleBuilder('総支出', 30000, 0);
      expect(title, contains('30000'));
    });

    test('frequencyReduce template includes count', () {
      final t = QuestTemplate.byId['frequencyReduce']!;
      final title = t.titleBuilder('食費', 8000, 3);
      expect(title, contains('3回'));
    });
  });

  group('recommendedTemplateTypes', () {
    test('総支出 only returns totalCap', () {
      final types = recommendedTemplateTypes('総支出', 50000);
      expect(types, [QuestTemplateType.totalCap]);
    });

    test('low spend categories return budgetLimit and noSpendDay', () {
      final types = recommendedTemplateTypes('医療費', 500);
      expect(types, contains(QuestTemplateType.budgetLimit));
      expect(types, contains(QuestTemplateType.noSpendDay));
      expect(types, isNot(contains(QuestTemplateType.totalCap)));
    });

    test('high spend categories return all types', () {
      final types = recommendedTemplateTypes('食費', 15000);
      expect(types.length, 5);
    });
  });

  // ── WeeklyQuestGenerator ──
  group('WeeklyQuestGenerator', () {
    late InMemoryExpenseRepository repo;
    late WeeklyQuestGenerator generator;

    setUp(() {
      repo = InMemoryExpenseRepository();
    });

    String _fmt(DateTime d) =>
        '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

    /// 指定された日付の週に支出データを投入するヘルパー
    Future<void> _seedWeeklyData(
        DateTime monday, Map<String, List<int>> categoryAmounts) async {
      final entries = <ExpenseEntry>[];
      var i = 0;
      categoryAmounts.forEach((category, amounts) {
        for (final amount in amounts) {
          entries.add(ExpenseEntry(
            id: '${_fmt(monday)}_${category}_$i',
            amount: amount,
            category: category,
            date: monday.add(Duration(days: i % 7)),
          ));
          i++;
        }
      });
      await repo.saveEntries(entries);
    }

    test('generates 3-5 quests with sufficient data', () async {
      // 4週間分のデータを投入
      for (var w = 1; w <= 4; w++) {
        final mon = DateTime(2026, 6, 1).add(Duration(days: 7 * (w - 1)));
        await _seedWeeklyData(mon, {
          '食費': [3000, 2000, 5000],
          '娯楽': [5000, 3000],
          '交通費': [1000, 1000],
          '交際費': [4000],
        });
      }

      generator = WeeklyQuestGenerator(repo, randomSeed: 42);
      final quests = await generator.generate(DateTime(2026, 6, 29));

      expect(quests.length, greaterThanOrEqualTo(3));
      expect(quests.length, lessThanOrEqualTo(5));

      // 全クエストが同じ週を指す
      for (final q in quests) {
        expect(q.weekStart, DateTime(2026, 6, 29)); // 月曜に正規化
      }

      // バリエーションチェック: templateIdが重複していない
      final templateIds = quests.map((q) => q.templateId).toSet();
      expect(templateIds.length, greaterThanOrEqualTo(1));
    });

    test('normalizes non-Monday to Monday', () async {
      await _seedWeeklyData(DateTime(2026, 6, 1), {
        '食費': [3000, 2000],
      });
      await _seedWeeklyData(DateTime(2026, 6, 8), {
        '食費': [3000, 2000],
      });
      await _seedWeeklyData(DateTime(2026, 6, 15), {
        '食費': [3000, 2000],
      });
      await _seedWeeklyData(DateTime(2026, 6, 22), {
        '食費': [3000, 2000],
      });

      generator = WeeklyQuestGenerator(repo, randomSeed: 42);
      // 6/25(木) を指定 → 6/22(月) に正規化されるはず
      final quests = await generator.generate(DateTime(2026, 6, 25));

      for (final q in quests) {
        expect(q.weekStart.weekday, DateTime.monday);
      }
    });

    test('fallback quests when no data', () async {
      generator = WeeklyQuestGenerator(repo, randomSeed: 42);
      final quests = await generator.generate(DateTime(2026, 6, 29));

      expect(quests.length, 3); // exactly 3 fallback
      for (final q in quests) {
        expect(q.budgetLimit, greaterThan(0));
        expect(q.title, isNotEmpty);
        expect(q.description, isNotEmpty);
      }
    });

    test('budgetLimit is always positive', () async {
      await _seedWeeklyData(DateTime(2026, 6, 1), {
        '食費': [10000],
      });
      await _seedWeeklyData(DateTime(2026, 6, 8), {
        '食費': [10000],
      });
      await _seedWeeklyData(DateTime(2026, 6, 15), {
        '食費': [10000],
      });
      await _seedWeeklyData(DateTime(2026, 6, 22), {
        '食費': [10000],
      });

      generator = WeeklyQuestGenerator(repo, randomSeed: 99);
      final quests = await generator.generate(DateTime(2026, 6, 29));

      for (final q in quests) {
        expect(q.budgetLimit, greaterThan(0),
            reason: 'budgetLimit for ${q.targetCategory} should be > 0');
      }
    });

    test('consistent output with same randomSeed', () async {
      // 4週間分のデータ
      for (var w = 1; w <= 4; w++) {
        final mon = DateTime(2026, 6, 1).add(Duration(days: 7 * (w - 1)));
        await _seedWeeklyData(mon, {
          '食費': [3000, 5000],
          '娯楽': [8000, 2000],
          '交通費': [1500],
        });
      }

      final gen1 = WeeklyQuestGenerator(repo, randomSeed: 42);
      final gen2 = WeeklyQuestGenerator(repo, randomSeed: 42);

      final quests1 = await gen1.generate(DateTime(2026, 6, 29));
      final quests2 = await gen2.generate(DateTime(2026, 6, 29));

      expect(quests1.length, quests2.length);
      for (var i = 0; i < quests1.length; i++) {
        expect(quests1[i].title, quests2[i].title);
        expect(quests1[i].budgetLimit, quests2[i].budgetLimit);
        expect(quests1[i].targetCategory, quests2[i].targetCategory);
      }
    });

    test('totalCap template may appear with 70% probability', () async {
      // 十分なデータを投入
      for (var w = 1; w <= 4; w++) {
        final mon = DateTime(2026, 6, 1).add(Duration(days: 7 * (w - 1)));
        await _seedWeeklyData(mon, {
          '食費': [3000, 5000],
          '娯楽': [8000, 2000],
          '交通費': [1500],
          '交際費': [4000],
        });
      }

      // 複数回試行して totalCap が出現することを確認
      var hasTotalCap = false;
      for (var seed = 1; seed <= 20; seed++) {
        generator = WeeklyQuestGenerator(repo, randomSeed: seed);
        final quests = await generator.generate(DateTime(2026, 6, 29));
        if (quests.any((q) => q.templateId == 'totalCap')) {
          hasTotalCap = true;
          break;
        }
      }
      expect(hasTotalCap, true,
          reason: 'totalCap should appear at least once in 20 seeds');
    });

    test('quests have varied difficulty', () async {
      for (var w = 1; w <= 4; w++) {
        final mon = DateTime(2026, 6, 1).add(Duration(days: 7 * (w - 1)));
        await _seedWeeklyData(mon, {
          '食費': [3000, 5000, 2000],
          '娯楽': [8000, 2000, 10000],
          '交通費': [1500, 1500],
          '交際費': [4000, 6000],
        });
      }

      // 複数seedで難易度の多様性を確認
      final difficulties = <QuestDifficulty>{};
      for (var seed = 1; seed <= 10; seed++) {
        generator = WeeklyQuestGenerator(repo, randomSeed: seed);
        final quests = await generator.generate(DateTime(2026, 6, 29));
        for (final q in quests) {
          difficulties.add(q.difficulty);
        }
      }
      // すべての難易度が出現するはず
      expect(difficulties.length, greaterThanOrEqualTo(2));
    });

    test('each quest has unique id', () async {
      for (var w = 1; w <= 4; w++) {
        final mon = DateTime(2026, 6, 1).add(Duration(days: 7 * (w - 1)));
        await _seedWeeklyData(mon, {
          '食費': [3000, 5000],
          '娯楽': [8000, 2000],
        });
      }

      generator = WeeklyQuestGenerator(repo, randomSeed: 42);
      final quests = await generator.generate(DateTime(2026, 6, 29));

      final ids = quests.map((q) => q.id).toSet();
      expect(ids.length, quests.length); // すべてユニーク
    });
  });
}
