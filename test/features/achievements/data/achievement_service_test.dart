import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/achievement_api_model.dart';
import 'package:kozuchi/domain/models/achievement_check_models.dart';
import 'package:kozuchi/features/achievements/data/achievement_service.dart';

void main() {
  group('AchievementApiModel', () {
    test('fromJson parses all fields correctly', () {
      final json = {
        'id': 1,
        'key': 'first_offering',
        'title': '初めての喜捨',
        'description': '最初の一歩',
        'criteria_type': 'offering_count',
        'criteria_value': 1,
        'icon': '🙏',
        'sort_order': 10,
        'unlocked': false,
        'unlocked_at': null,
        'progress': null,
      };

      final model = AchievementApiModel.fromJson(
        Map<String, dynamic>.from(json),
      );

      expect(model.id, 1);
      expect(model.key, 'first_offering');
      expect(model.title, '初めての喜捨');
      expect(model.description, '最初の一歩');
      expect(model.criteriaType, 'offering_count');
      expect(model.criteriaValue, 1);
      expect(model.icon, '🙏');
      expect(model.sortOrder, 10);
      expect(model.unlocked, false);
      expect(model.unlockedAt, isNull);
      expect(model.progress, isNull);
    });

    test('fromJson parses unlocked achievement with progress', () {
      final json = {
        'id': 2,
        'key': 'total_10000',
        'title': '壱万円突破',
        'description': '累計1万円',
        'criteria_type': 'total_donation',
        'criteria_value': 10000,
        'icon': '💰',
        'sort_order': 20,
        'unlocked': true,
        'unlocked_at': '2026-06-25T10:00:00Z',
        'progress': null,
      };

      final model = AchievementApiModel.fromJson(
        Map<String, dynamic>.from(json),
      );

      expect(model.unlocked, true);
      expect(model.unlockedAt, '2026-06-25T10:00:00Z');
      expect(model.progressFraction, isNull);
      expect(model.progressText, isNull);
    });

    test('progressText formats total_donation correctly', () {
      final model = AchievementApiModel(
        id: 1,
        key: 'test',
        title: 'Test',
        description: 'Test',
        criteriaType: 'total_donation',
        criteriaValue: 100000,
        icon: '💰',
        sortOrder: 0,
        unlocked: false,
        progress: const AchievementProgress(
          current: 35000,
          target: 100000,
          pct: 35.0,
        ),
      );

      expect(model.progressText, '¥3万 / ¥10万');
      expect(model.progressFraction, 0.35);
    });

    test('progressText formats streak_days correctly', () {
      final model = AchievementApiModel(
        id: 1,
        key: 'test',
        title: 'Test',
        description: 'Test',
        criteriaType: 'streak_days',
        criteriaValue: 30,
        icon: '🔥',
        sortOrder: 0,
        unlocked: false,
        progress: const AchievementProgress(
          current: 15,
          target: 30,
          pct: 50.0,
        ),
      );

      expect(model.progressText, '15 / 30日');
      expect(model.progressFraction, 0.5);
    });

    test('progressText formats offering_count correctly', () {
      final model = AchievementApiModel(
        id: 1,
        key: 'test',
        title: 'Test',
        description: 'Test',
        criteriaType: 'offering_count',
        criteriaValue: 100,
        icon: '📿',
        sortOrder: 0,
        unlocked: false,
        progress: const AchievementProgress(
          current: 42,
          target: 100,
          pct: 42.0,
        ),
      );

      expect(model.progressText, '42 / 100回');
      expect(model.progressFraction, 0.42);
    });
  });

  group('AchievementCheckRequest', () {
    test('toJson includes all fields', () {
      const request = AchievementCheckRequest(
        userId: 'test_user',
        offeringCount: 5,
        totalDonation: 5000,
        streakDays: 3,
        categoriesUsed: 2,
        satoriLevel: 45,
        guardiansTried: 1,
        receiptCount: 3,
        budgetSetCount: 2,
        budgetPerfectDays: 1,
      );

      final json = request.toJson();
      expect(json['user_id'], 'test_user');
      expect(json['offering_count'], 5);
      expect(json['total_donation'], 5000);
      expect(json['streak_days'], 3);
      expect(json['categories_used'], 2);
      expect(json['satori_level'], 45);
      expect(json['guardians_tried'], 1);
      expect(json['receipt_count'], 3);
      expect(json['budget_set_count'], 2);
      expect(json['budget_perfect_days'], 1);
    });
  });

  group('AchievementCheckResponse', () {
    test('fromJson parses newly unlocked achievements', () {
      final json = {
        'newly_unlocked': [
          {
            'id': 1,
            'key': 'first_offering',
            'title': '初めての喜捨',
            'description': '最初の一歩',
            'criteria_type': 'offering_count',
            'criteria_value': 1,
            'icon': '🙏',
            'sort_order': 10,
            'unlocked': true,
            'unlocked_at': '2026-06-25T10:00:00Z',
          },
        ],
        'already_unlocked_count': 3,
        'total_achievements': 25,
      };

      final response = AchievementCheckResponse.fromJson(
        Map<String, dynamic>.from(json),
      );

      expect(response.newlyUnlocked.length, 1);
      expect(response.newlyUnlocked.first.title, '初めての喜捨');
      expect(response.alreadyUnlockedCount, 3);
      expect(response.totalAchievements, 25);
    });

    test('fromJson handles empty newly_unlocked', () {
      final json = {
        'newly_unlocked': [],
        'already_unlocked_count': 5,
        'total_achievements': 25,
      };

      final response = AchievementCheckResponse.fromJson(
        Map<String, dynamic>.from(json),
      );

      expect(response.newlyUnlocked, isEmpty);
      expect(response.alreadyUnlockedCount, 5);
    });
  });

  group('AchievementService', () {
    test('fetchAchievements with fetchOverride returns mocked data', () async {
      final mockData = [
        AchievementApiModel(
          id: 1,
          key: 'test',
          title: 'Test',
          description: 'Test desc',
          criteriaType: 'test',
          criteriaValue: 1,
          icon: '🏆',
          sortOrder: 0,
          unlocked: false,
        ),
      ];

      final service = AchievementService(
        fetchOverride: ({String? userId}) async => mockData,
      );

      final result = await service.fetchAchievements(userId: 'test');
      expect(result.length, 1);
      expect(result.first.title, 'Test');
    });
  });
}
