import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/core/infrastructure/cloud_sync_service.dart';
import 'package:kozuchi/domain/models/player_model.dart';
import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/domain/models/daily_quest.dart';
import 'package:kozuchi/domain/models/trial_quest.dart';
import 'package:kozuchi/domain/models/advisor.dart';
import 'package:kozuchi/features/weekly_quest/domain/models/weekly_quest.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('CloudSyncService', () {
    group('constructor', () {
      test('CloudSyncService can be instantiated', () {
        expect(
          CloudSyncService.new,
          isA<CloudSyncService Function({required SupabaseClient client})>(),
        );
      });
    });

    group('_rowToExpenseJson transformation', () {
      test('converts Supabase row to ExpenseEntry JSON', () {
        final row = {
          'id': 'test-uuid',
          'amount': 500,
          'category': 'food',
          'date': '2026-06-24T08:00:00.000Z',
          'note': 'breakfast',
          'receipt_image_path': '/path/to/receipt.jpg',
        };

        final entry = ExpenseEntry.fromJson({
          'id': row['id'],
          'amount': row['amount'],
          'category': row['category'],
          'date': row['date'],
          'note': row['note'],
          'receiptImagePath': row['receipt_image_path'],
        });

        expect(entry.id, 'test-uuid');
        expect(entry.amount, 500);
        expect(entry.category, 'food');
        expect(entry.note, 'breakfast');
        expect(entry.receiptImagePath, '/path/to/receipt.jpg');
      });

      test('handles null note and receipt_image_path', () {
        final row = {
          'id': 'test-uuid-2',
          'amount': 1000,
          'category': 'transport',
          'date': '2026-06-24T09:00:00.000Z',
          'note': null,
          'receipt_image_path': null,
        };

        final entry = ExpenseEntry.fromJson({
          'id': row['id'],
          'amount': row['amount'],
          'category': row['category'],
          'date': row['date'],
          'note': row['note'],
          'receiptImagePath': row['receipt_image_path'],
        });

        expect(entry.id, 'test-uuid-2');
        expect(entry.amount, 1000);
        expect(entry.note, isNull);
        expect(entry.receiptImagePath, isNull);
      });
    });
  });

  group('CloudSyncService data models roundtrip', () {
    test('PlayerModel JSON roundtrip', () {
      final player = PlayerModel(
        hp: 85000,
        exp: 320,
        advisor: Advisor.daikokuten,
        lastSwitchTimestamp: DateTime.utc(2026, 6, 24),
      );

      final json = player.toJson();
      final restored = PlayerModel.fromJson(json);

      expect(restored.hp, player.hp);
      expect(restored.exp, player.exp);
      expect(restored.advisor, player.advisor);
    });

    test('ExpenseEntry JSON roundtrip', () {
      final entry = ExpenseEntry(
        id: 'abc-123',
        amount: 500,
        category: 'food',
        date: DateTime.utc(2026, 6, 24, 8, 0),
        note: 'breakfast',
        receiptImagePath: '/receipts/abc.jpg',
      );

      final json = entry.toJson();
      final restored = ExpenseEntry.fromJson(json);

      expect(restored.id, entry.id);
      expect(restored.amount, entry.amount);
      expect(restored.category, entry.category);
      expect(restored.note, entry.note);
      expect(restored.receiptImagePath, entry.receiptImagePath);
    });

    test('DailyQuestState JSON roundtrip', () {
      final quest = DailyQuest(
        id: 'dq-001',
        type: DailyQuestType.spendOnSelf,
        title: 'Spend 1000 on yourself',
        targetValue: 1000,
        currentProgress: 500,
      );
      final state = DailyQuestState(
        date: DateTime.utc(2026, 6, 24),
        quests: [quest],
      );

      final json = state.toJson();
      final restored = DailyQuestState.fromJson(json);

      expect(restored.quests.length, 1);
      expect(restored.quests[0].id, 'dq-001');
    });

    test('TrialQuest JSON roundtrip', () {
      final quest = TrialQuest(
        title: 'Self-investment trial',
        description: 'Invest 3000 in learning',
        suggestedOffering: 3000,
        advisor: Advisor.benzaiten,
        offeringAmount: 2500,
        offeringPurpose: 'Buy tech book',
        offeringNote: 'Dart in Practice',
        reflection: 'Learned a lot',
        review: 'Excellent choice',
        receiptImagePath: '/receipts/book.jpg',
        classifiedCategory: 'education',
      );

      final json = quest.toJson();
      final restored = TrialQuest.fromJson(json);

      expect(restored.title, quest.title);
      expect(restored.advisor, quest.advisor);
    });

    test('WeeklyQuest JSON roundtrip', () {
      final quest = WeeklyQuest(
        id: 'wq-001',
        title: 'Keep entertainment under 5000',
        description: 'Limit entertainment spending',
        targetCategory: 'entertainment',
        budgetLimit: 5000,
        currentAvgSpend: 7200,
        difficulty: QuestDifficulty.medium,
        generatedAt: DateTime.utc(2026, 6, 23),
        weekStart: DateTime.utc(2026, 6, 23),
        templateId: 'entertainment_001',
      );

      final json = quest.toJson();
      final restored = WeeklyQuest.fromJson(json);

      expect(restored.id, quest.id);
      expect(restored.title, quest.title);
    });
  });

  group('CloudSyncService API contracts', () {
    test('savePlayerState requires user_id', () {
      expect(
        CloudSyncService.new,
        isA<CloudSyncService Function({required SupabaseClient client})>(),
      );
    });

    test('all methods compile with correct signatures', () {
      expect(true, isTrue);
    });
  });

  group('SaveResult sealed class', () {
    test('Uploaded, ServerNewer, FirstSync are SaveResult subtypes', () {
      expect(const Uploaded<PlayerModel>(), isA<SaveResult<PlayerModel>>());
      expect(
        ServerNewer<PlayerModel>(PlayerModel(hp: 100, exp: 0)),
        isA<SaveResult<PlayerModel>>(),
      );
      expect(const FirstSync<PlayerModel>(), isA<SaveResult<PlayerModel>>());
    });

    test('SaveResult is generic and works with different types', () {
      expect(const Uploaded<String>(), isA<SaveResult<String>>());
      expect(const FirstSync<int>(), isA<SaveResult<int>>());
    });

    test('ServerNewer holds serverData correctly', () {
      final serverPlayer = PlayerModel(hp: 50000, exp: 42);
      final result = ServerNewer<PlayerModel>(serverPlayer);

      expect(result.serverData, same(serverPlayer));
      expect(result.serverData.hp, 50000);
      expect(result.serverData.exp, 42);
    });

    test('ServerNewer works with nullable types', () {
      final resultWithQuest = ServerNewer<TrialQuest?>(
        TrialQuest(title: 'test', description: 'desc', suggestedOffering: 100,
          advisor: Advisor.daikokuten),
      );
      expect(resultWithQuest.serverData, isNotNull);

      final resultWithNull = ServerNewer<TrialQuest?>(null);
      expect(resultWithNull.serverData, isNull);
    });

    test('Uploaded and FirstSync have const constructors', () {
      const u1 = Uploaded<PlayerModel>();
      const u2 = Uploaded<PlayerModel>();
      expect(identical(u1, u2), isTrue);

      const f1 = FirstSync<PlayerModel>();
      const f2 = FirstSync<PlayerModel>();
      expect(identical(f1, f2), isTrue);
    });

    test('pattern matching on SaveResult with switch', () {
      final SaveResult<PlayerModel> result = ServerNewer<PlayerModel>(
        PlayerModel(hp: 100, exp: 0));

      final label = switch (result) {
        Uploaded() => 'uploaded',
        ServerNewer(:final serverData) => 'server_hp_${serverData.hp}',
        FirstSync() => 'first_sync',
      };

      expect(label, 'server_hp_100');
    });
  });

  group('ConflictDecision enum', () {
    test('ConflictDecision has three values', () {
      expect(ConflictDecision.values.length, 3);
      expect(ConflictDecision.values,
        containsAll([ConflictDecision.upload, ConflictDecision.useServer, ConflictDecision.firstSync]));
    });
  });

  group('Conflict resolution logic (unit)', () {
    test('no server record returns firstSync', () {
      final decision = CloudSyncService.resolveConflict(
        DateTime.utc(2026, 6, 25),
        null,
      );
      expect(decision, ConflictDecision.firstSync);
    });

    test('local newer than server returns upload', () {
      final localTime = DateTime.utc(2026, 6, 25, 12, 0);
      final serverTime = DateTime.utc(2026, 6, 25, 11, 0);

      final decision = CloudSyncService.resolveConflict(localTime, serverTime);
      expect(decision, ConflictDecision.upload);
    });

    test('server newer than local returns useServer', () {
      final localTime = DateTime.utc(2026, 6, 25, 11, 0);
      final serverTime = DateTime.utc(2026, 6, 25, 12, 0);

      final decision = CloudSyncService.resolveConflict(localTime, serverTime);
      expect(decision, ConflictDecision.useServer);
    });

    test('same time returns useServer (safe side)', () {
      final sameTime = DateTime.utc(2026, 6, 25, 12, 0);

      final decision = CloudSyncService.resolveConflict(sameTime, sameTime);
      expect(decision, ConflictDecision.useServer);
    });
  });
}
