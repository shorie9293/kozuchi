import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/goal.dart';

void main() {
  final testNow = DateTime(2026, 6, 24, 12, 0, 0);

  /// テスト用の Goal を生成するヘルパー
  Goal testGoal({
    String id = 'goal-001',
    String title = '月末までに¥50,000貯める',
    int targetAmount = 50000,
    DateTime? deadline,
    int currentAmount = 0,
    GoalStatus status = GoalStatus.active,
  }) {
    return Goal(
      id: id,
      title: title,
      targetAmount: targetAmount,
      deadline: deadline,
      currentAmount: currentAmount,
      status: status,
      createdAt: testNow,
      updatedAt: testNow,
    );
  }

  group('Goal', () {
    group('進捗計算', () {
      test('進捗率が正しく計算される（50%）', () {
        final goal = testGoal(targetAmount: 100000, currentAmount: 50000);
        expect(goal.progress, 0.5);
      });

      test('進捗率が正しく計算される（0%）', () {
        final goal = testGoal(targetAmount: 100000, currentAmount: 0);
        expect(goal.progress, 0.0);
      });

      test('進捗率が正しく計算される（100%）', () {
        final goal = testGoal(targetAmount: 100000, currentAmount: 100000);
        expect(goal.progress, 1.0);
      });

      test('目標額が0の場合は進捗率0%', () {
        final goal = testGoal(targetAmount: 0, currentAmount: 50000);
        expect(goal.progress, 0.0);
      });

      test('進捗百分率が正しく計算される', () {
        final goal = testGoal(targetAmount: 50000, currentAmount: 12500);
        expect(goal.progressPercent, 25);
      });
    });

    group('期限管理', () {
      test('期限切れでない目標', () {
        final future = DateTime.now().add(const Duration(days: 7));
        final goal = testGoal(deadline: future);
        expect(goal.isOverdue, isFalse);
      });

      test('期限切れの目標（過去の期限）', () {
        final past = DateTime.now().subtract(const Duration(days: 1));
        final goal = testGoal(deadline: past);
        expect(goal.isOverdue, isTrue);
      });

      test('期限切れでも完了済みなら期限切れとみなさない', () {
        final past = DateTime.now().subtract(const Duration(days: 1));
        final goal = testGoal(
          deadline: past,
          status: GoalStatus.completed,
        );
        expect(goal.isOverdue, isFalse);
      });

      test('期限がない場合は期限切れではない', () {
        final goal = testGoal(deadline: null);
        expect(goal.isOverdue, isFalse);
      });

      test('残り日数が正しく計算される', () {
        final future = DateTime.now().add(const Duration(days: 3));
        final goal = testGoal(deadline: future);
        expect(goal.remainingDays, greaterThanOrEqualTo(2));
        expect(goal.remainingDays, lessThanOrEqualTo(3));
      });

      test('期限がない場合は残り日数もnull', () {
        final goal = testGoal(deadline: null);
        expect(goal.remainingDays, isNull);
      });
    });

    group('進捗更新', () {
      test('進捗更新でcurrentAmountが更新される', () {
        final goal = testGoal(targetAmount: 100000, currentAmount: 0);
        final updated = goal.updateProgress(30000);
        expect(updated.currentAmount, 30000);
      });

      test('目標額に達すると自動的にcompletedになる', () {
        final goal = testGoal(targetAmount: 50000, currentAmount: 30000);
        final updated = goal.updateProgress(50000);
        expect(updated.status, GoalStatus.completed);
        expect(updated.currentAmount, 50000);
      });

      test('目標額を超える進捗は目標額にクランプされる', () {
        final goal = testGoal(targetAmount: 50000, currentAmount: 30000);
        final updated = goal.updateProgress(100000);
        expect(updated.currentAmount, 50000);
      });

      test('進捗更新時にupdatedAtが更新される', () {
        final goal = testGoal(targetAmount: 100000, currentAmount: 0);
        final updated = goal.updateProgress(20000);
        expect(updated.updatedAt, isNot(goal.updatedAt));
        expect(updated.createdAt, goal.createdAt); // createdAtは不変
      });
    });

    group('状態変更', () {
      test('アクティブから完了に変更できる', () {
        final goal = testGoal(status: GoalStatus.active);
        final updated = goal.copyWithStatus(GoalStatus.completed);
        expect(updated.status, GoalStatus.completed);
      });

      test('完了からアクティブに戻せる', () {
        final goal = testGoal(status: GoalStatus.completed);
        final updated = goal.copyWithStatus(GoalStatus.active);
        expect(updated.status, GoalStatus.active);
      });
    });

    group('JSONシリアライズ', () {
      test('toJson → fromJson 往復で同一オブジェクトが復元される', () {
        final deadline = DateTime(2026, 7, 31);
        final goal = Goal(
          id: 'goal-001',
          userId: 'default',
          title: '月末までに¥50,000貯める',
          targetAmount: 50000,
          deadline: deadline,
          currentAmount: 15000,
          status: GoalStatus.active,
          createdAt: testNow,
          updatedAt: testNow,
        );

        final json = goal.toJson();
        final restored = Goal.fromJson(json);

        expect(restored.id, goal.id);
        expect(restored.userId, goal.userId);
        expect(restored.title, goal.title);
        expect(restored.targetAmount, goal.targetAmount);
        expect(restored.deadline?.toIso8601String(),
            goal.deadline?.toIso8601String());
        expect(restored.currentAmount, goal.currentAmount);
        expect(restored.status, goal.status);
      });

      test('deadlineがnullの場合も往復で正しく復元される', () {
        final goal = Goal(
          id: 'goal-002',
          title: '毎日読書30分',
          targetAmount: 0,
          deadline: null,
          currentAmount: 0,
          status: GoalStatus.active,
          createdAt: testNow,
          updatedAt: testNow,
        );

        final json = goal.toJson();
        final restored = Goal.fromJson(json);

        expect(restored.deadline, isNull);
        expect(restored.targetAmount, 0);
      });

      test('statusが文字列から正しくパースされる', () {
        final json = {
          'id': 'g1',
          'title': 'test',
          'targetAmount': 1000,
          'currentAmount': 0,
          'status': 'completed',
          'createdAt': testNow.toIso8601String(),
          'updatedAt': testNow.toIso8601String(),
        };
        final goal = Goal.fromJson(json);
        expect(goal.status, GoalStatus.completed);
      });

      test('不明なstatus文字列はactiveにフォールバック', () {
        final json = {
          'id': 'g1',
          'title': 'test',
          'targetAmount': 1000,
          'currentAmount': 0,
          'status': 'unknown',
          'createdAt': testNow.toIso8601String(),
          'updatedAt': testNow.toIso8601String(),
        };
        final goal = Goal.fromJson(json);
        expect(goal.status, GoalStatus.active);
      });
    });

    group('称号生成', () {
      test('アクティブな目標からは称号が生成されない', () {
        final goal = testGoal(status: GoalStatus.active);
        expect(goal.generateAchievement(), isNull);
      });

      test('完了した目標から称号が生成される', () {
        final goal = testGoal(
          targetAmount: 50000,
          status: GoalStatus.completed,
        );
        final achievement = goal.generateAchievement();
        expect(achievement, isNotNull);
        expect(achievement!.goalId, goal.id);
      });

      test('目標額に応じた称号が生成される（10万円未満）', () {
        final goal = testGoal(
          targetAmount: 50000,
          status: GoalStatus.completed,
        );
        final achievement = goal.generateAchievement();
        expect(achievement!.title, '蓄財の心得');
      });

      test('目標額に応じた称号が生成される（100万円以上）', () {
        final goal = testGoal(
          targetAmount: 2000000,
          status: GoalStatus.completed,
        );
        final achievement = goal.generateAchievement();
        expect(achievement!.title, '伝説の蓄財王');
      });

      test('目標額0（習慣目標）の称号', () {
        final goal = testGoal(
          targetAmount: 0,
          status: GoalStatus.completed,
        );
        final achievement = goal.generateAchievement();
        expect(achievement!.title, '習慣の達人');
      });
    });
  });
}
