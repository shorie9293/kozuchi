import 'package:test/test.dart';
import 'package:kozuchi/features/weekly_quest/domain/models/weekly_quest.dart';
import 'package:kozuchi/features/weekly_quest/domain/models/active_weekly_quest.dart';

void main() {
  final sampleQuest = WeeklyQuest(
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

  group('ActiveWeeklyQuest', () {
    test('creates with pending status by default', () {
      final active = ActiveWeeklyQuest(quest: sampleQuest);
      expect(active.quest, sampleQuest);
      expect(active.status, WeeklyQuestStatus.pending);
    });

    test('creates with explicit status', () {
      final active = ActiveWeeklyQuest(
        quest: sampleQuest,
        status: WeeklyQuestStatus.active,
      );
      expect(active.status, WeeklyQuestStatus.active);
    });

    test('activate() transitions pending to active', () {
      final active = ActiveWeeklyQuest(quest: sampleQuest);
      final activated = active.activate();
      expect(activated.status, WeeklyQuestStatus.active);
    });

    test('complete() transitions active to completed', () {
      final active = ActiveWeeklyQuest(
        quest: sampleQuest,
        status: WeeklyQuestStatus.active,
      );
      final completed = active.complete();
      expect(completed.status, WeeklyQuestStatus.completed);
    });

    test('fail() transitions active to failed', () {
      final active = ActiveWeeklyQuest(
        quest: sampleQuest,
        status: WeeklyQuestStatus.active,
      );
      final failed = active.fail();
      expect(failed.status, WeeklyQuestStatus.failed);
    });

    test('isActive returns true only for active status', () {
      expect(
        ActiveWeeklyQuest(quest: sampleQuest).isActive,
        false,
      );
      expect(
        ActiveWeeklyQuest(
          quest: sampleQuest,
          status: WeeklyQuestStatus.active,
        ).isActive,
        true,
      );
      expect(
        ActiveWeeklyQuest(
          quest: sampleQuest,
          status: WeeklyQuestStatus.completed,
        ).isActive,
        false,
      );
    });

    test('JSON serialization roundtrip', () {
      final active = ActiveWeeklyQuest(
        quest: sampleQuest,
        status: WeeklyQuestStatus.active,
        selectedAt: DateTime(2026, 6, 23, 10, 0),
      );
      final json = active.toJson();
      final restored = ActiveWeeklyQuest.fromJson(json);

      expect(restored.quest.id, active.quest.id);
      expect(restored.quest.title, active.quest.title);
      expect(restored.quest.budgetLimit, active.quest.budgetLimit);
      expect(restored.status, WeeklyQuestStatus.active);
      expect(restored.selectedAt, DateTime(2026, 6, 23, 10, 0));
    });

    test('JSON roundtrip without selectedAt', () {
      final active = ActiveWeeklyQuest(quest: sampleQuest);
      final json = active.toJson();
      final restored = ActiveWeeklyQuest.fromJson(json);

      expect(restored.status, WeeklyQuestStatus.pending);
      expect(restored.selectedAt, isNull);
    });
  });

  group('WeeklyQuestStatus', () {
    test('values list contains all 4 statuses', () {
      expect(WeeklyQuestStatus.values.length, 4);
    });

    test('label returns Japanese', () {
      expect(WeeklyQuestStatus.pending.label, '選択待ち');
      expect(WeeklyQuestStatus.active.label, '挑戦中');
      expect(WeeklyQuestStatus.completed.label, '達成');
      expect(WeeklyQuestStatus.failed.label, '失敗');
    });
  });
}
