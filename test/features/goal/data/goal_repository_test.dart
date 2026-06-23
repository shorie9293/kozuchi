import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/domain/models/goal.dart';
import 'package:kozuchi/domain/models/achievement.dart';
import 'package:kozuchi/features/goal/data/goal_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GoalRepository repository;
  final testNow = DateTime(2026, 6, 24, 12, 0, 0);

  /// テスト用 Goal を生成
  Goal makeGoal({
    String id = 'goal-001',
    String title = 'テスト目標',
    int targetAmount = 100000,
    int currentAmount = 0,
    GoalStatus status = GoalStatus.active,
  }) {
    return Goal(
      id: id,
      title: title,
      targetAmount: targetAmount,
      currentAmount: currentAmount,
      status: status,
      createdAt: testNow,
      updatedAt: testNow,
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = const GoalRepository();
    await repository.initialize();
  });

  group('GoalRepository', () {
    group('初期化とマイグレーション', () {
      test('initializeで空の状態から問題なく起動できる', () async {
        // setupでinitialize済み。エラーなく通過すればOK
        final goals = await repository.getAllGoals();
        expect(goals, isEmpty);
      });

      test('既存データがある状態で再初期化してもデータが失われない', () async {
        final goal = makeGoal();
        await repository.createGoal(goal);

        // 再初期化
        await repository.initialize();

        final loaded = await repository.getGoalById(goal.id);
        expect(loaded, isNotNull);
        expect(loaded!.title, goal.title);
      });
    });

    group('createGoal', () {
      test('目標を作成して読み出せる', () async {
        final goal = makeGoal();
        final created = await repository.createGoal(goal);

        expect(created.id, goal.id);
        expect(created.title, goal.title);

        final all = await repository.getAllGoals();
        expect(all.length, 1);
        expect(all.first.id, goal.id);
      });

      test('複数の目標を同時に管理できる', () async {
        final goal1 = makeGoal(id: 'goal-001', title: '目標1');
        final goal2 = makeGoal(id: 'goal-002', title: '目標2');
        final goal3 = makeGoal(id: 'goal-003', title: '目標3');

        await repository.createGoal(goal1);
        await repository.createGoal(goal2);
        await repository.createGoal(goal3);

        final all = await repository.getAllGoals();
        expect(all.length, 3);
      });
    });

    group('getAllGoals', () {
      test('空の状態では空リストが返る', () async {
        final goals = await repository.getAllGoals();
        expect(goals, isEmpty);
      });

      test('作成日時の降順で返る', () async {
        final early = Goal(
          id: 'goal-early',
          title: '古い目標',
          targetAmount: 10000,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        );
        final late = Goal(
          id: 'goal-late',
          title: '新しい目標',
          targetAmount: 20000,
          createdAt: DateTime(2026, 6, 1),
          updatedAt: DateTime(2026, 6, 1),
        );

        await repository.createGoal(early);
        await repository.createGoal(late);

        final all = await repository.getAllGoals();
        expect(all.first.id, 'goal-late');
        expect(all.last.id, 'goal-early');
      });
    });

    group('getActiveGoals', () {
      test('アクティブな目標のみが返る', () async {
        await repository.createGoal(
            makeGoal(id: 'g1', title: 'active1', status: GoalStatus.active));
        await repository.createGoal(
            makeGoal(id: 'g2', title: 'active2', status: GoalStatus.active));
        await repository.createGoal(makeGoal(
            id: 'g3', title: 'completed1', status: GoalStatus.completed));

        final active = await repository.getActiveGoals();
        expect(active.length, 2);
        expect(active.every((g) => g.status == GoalStatus.active), isTrue);
      });
    });

    group('getCompletedGoals', () {
      test('完了した目標のみが返る', () async {
        await repository.createGoal(
            makeGoal(id: 'g1', title: 'active1', status: GoalStatus.active));
        await repository.createGoal(makeGoal(
            id: 'g2', title: 'completed1', status: GoalStatus.completed));

        final completed = await repository.getCompletedGoals();
        expect(completed.length, 1);
        expect(completed.first.id, 'g2');
      });
    });

    group('getGoalById', () {
      test('存在するIDで検索できる', () async {
        final goal = makeGoal(id: 'goal-001');
        await repository.createGoal(goal);

        final found = await repository.getGoalById('goal-001');
        expect(found, isNotNull);
        expect(found!.id, 'goal-001');
      });

      test('存在しないIDではnullが返る', () async {
        final found = await repository.getGoalById('nonexistent');
        expect(found, isNull);
      });
    });

    group('updateGoal', () {
      test('目標を更新できる', () async {
        final goal = makeGoal(id: 'goal-001', title: '元のタイトル');
        await repository.createGoal(goal);

        final updated = Goal(
          id: 'goal-001',
          title: '更新後のタイトル',
          targetAmount: 200000,
          createdAt: testNow,
          updatedAt: DateTime.now(),
        );
        await repository.updateGoal(updated);

        final loaded = await repository.getGoalById('goal-001');
        expect(loaded!.title, '更新後のタイトル');
        expect(loaded.targetAmount, 200000);
      });
    });

    group('updateGoalProgress', () {
      test('進捗を更新できる', () async {
        final goal = makeGoal(
          id: 'goal-001',
          targetAmount: 100000,
          currentAmount: 0,
        );
        await repository.createGoal(goal);

        await repository.updateGoalProgress('goal-001', 30000);

        final updated = await repository.getGoalById('goal-001');
        expect(updated!.currentAmount, 30000);
      });

      test('目標達成時にcompletedになり称号が生成される', () async {
        final goal = makeGoal(
          id: 'goal-001',
          targetAmount: 50000,
          currentAmount: 30000,
        );
        await repository.createGoal(goal);

        final achievement =
            await repository.updateGoalProgress('goal-001', 50000);

        expect(achievement, isNotNull);
        expect(achievement!.goalId, 'goal-001');

        final updated = await repository.getGoalById('goal-001');
        expect(updated!.status, GoalStatus.completed);
      });

      test('進捗更新で達成しなかった場合、称号は生成されない', () async {
        final goal = makeGoal(
          id: 'goal-001',
          targetAmount: 100000,
          currentAmount: 0,
        );
        await repository.createGoal(goal);

        final achievement =
            await repository.updateGoalProgress('goal-001', 50000);

        expect(achievement, isNull);
      });
    });

    group('deleteGoal', () {
      test('目標を削除できる', () async {
        final goal = makeGoal(id: 'goal-001');
        await repository.createGoal(goal);

        await repository.deleteGoal('goal-001');

        final found = await repository.getGoalById('goal-001');
        expect(found, isNull);
      });
    });

    group('Achievement管理', () {
      test('称号を追加して読み出せる', () async {
        final achievement = Achievement(
          id: 'achv-001',
          title: 'テスト称号',
          description: 'テスト説明',
          earnedAt: testNow,
          goalId: 'goal-001',
        );

        await repository.addAchievement(achievement);

        final all = await repository.getAllAchievements();
        expect(all.length, 1);
        expect(all.first.title, 'テスト称号');
      });

      test('getAchievementsForGoalで紐づく称号のみ取得できる', () async {
        await repository.addAchievement(Achievement(
          id: 'achv-1',
          title: '称号1',
          description: 'desc1',
          earnedAt: testNow,
          goalId: 'goal-001',
        ));
        await repository.addAchievement(Achievement(
          id: 'achv-2',
          title: '称号2',
          description: 'desc2',
          earnedAt: testNow,
          goalId: 'goal-002',
        ));

        final forGoal1 = await repository.getAchievementsForGoal('goal-001');
        expect(forGoal1.length, 1);
        expect(forGoal1.first.goalId, 'goal-001');
      });
    });
  });
}
