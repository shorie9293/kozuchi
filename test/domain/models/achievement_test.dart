import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/achievement.dart';
import 'package:kozuchi/domain/models/goal.dart';

void main() {
  final testNow = DateTime(2026, 6, 24, 12, 0, 0);

  group('Achievement', () {
    group('JSONシリアライズ', () {
      test('toJson → fromJson 往復で同一オブジェクトが復元される', () {
        final achievement = Achievement(
          id: 'achv-001',
          title: '蓄財の心得',
          description: '「月末までに¥50,000貯める」を見事達成。着実な前進。',
          earnedAt: testNow,
          goalId: 'goal-001',
        );

        final json = achievement.toJson();
        final restored = Achievement.fromJson(json);

        expect(restored.id, achievement.id);
        expect(restored.title, achievement.title);
        expect(restored.description, achievement.description);
        expect(restored.earnedAt.toIso8601String(),
            achievement.earnedAt.toIso8601String());
        expect(restored.goalId, achievement.goalId);
      });

      test('goalIdがnullの場合も往復で正しく復元される', () {
        final achievement = Achievement(
          id: 'achv-002',
          title: 'テスト称号',
          description: '説明',
          earnedAt: testNow,
          goalId: null,
        );

        final json = achievement.toJson();
        final restored = Achievement.fromJson(json);

        expect(restored.goalId, isNull);
      });
    });

    group('forGoal ファクトリ', () {
      test('目標から称号が正しく生成される（10万円未満）', () {
        final goal = Goal(
          id: 'goal-001',
          title: '月末までに¥50,000貯める',
          targetAmount: 50000,
          currentAmount: 50000,
          status: GoalStatus.completed,
          createdAt: testNow,
          updatedAt: testNow,
        );

        final achievement = Achievement.forGoal(goal);
        expect(achievement.title, '蓄財の心得');
        expect(achievement.goalId, 'goal-001');
      });

      test('目標から称号が正しく生成される（100万円以上）', () {
        final goal = Goal(
          id: 'goal-002',
          title: 'マイホーム頭金200万円',
          targetAmount: 2000000,
          currentAmount: 2000000,
          status: GoalStatus.completed,
          createdAt: testNow,
          updatedAt: testNow,
        );

        final achievement = Achievement.forGoal(goal);
        expect(achievement.title, '伝説の蓄財王');
      });

      test('目標額0（習慣系）の称号', () {
        final goal = Goal(
          id: 'goal-003',
          title: '毎日読書30分',
          targetAmount: 0,
          currentAmount: 0,
          status: GoalStatus.completed,
          createdAt: testNow,
          updatedAt: testNow,
        );

        final achievement = Achievement.forGoal(goal);
        expect(achievement.title, '習慣の達人');
      });

      test('目標額1万円未満の称号', () {
        final goal = Goal(
          id: 'goal-004',
          title: 'コーヒー代節約',
          targetAmount: 5000,
          currentAmount: 5000,
          status: GoalStatus.completed,
          createdAt: testNow,
          updatedAt: testNow,
        );

        final achievement = Achievement.forGoal(goal);
        expect(achievement.title, '小さな一歩');
      });
    });
  });
}
