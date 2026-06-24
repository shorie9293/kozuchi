import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/goals/data/goal.dart';

void main() {
  group('Goal.fromJson', () {
    test('parses active goal correctly', () {
      final json = {
        'id': 'abc-123',
        'user_id': 'user_001',
        'title': 'Test Goal',
        'target_amount': 100000,
        'deadline': '2026-12-31',
        'current_amount': 30000,
        'status': 'active',
        'progress_percent': 30.0,
        'created_at': '2026-06-24T12:00:00',
        'updated_at': '2026-06-24T12:00:00',
      };

      final goal = Goal.fromJson(json);
      expect(goal.id, 'abc-123');
      expect(goal.title, 'Test Goal');
      expect(goal.targetAmount, 100000);
      expect(goal.currentAmount, 30000);
      expect(goal.status, 'active');
      expect(goal.progressPercent, 30.0);
      expect(goal.deadline, '2026-12-31');
      expect(goal.isActive, true);
      expect(goal.isCompleted, false);
      expect(goal.isCancelled, false);
      expect(goal.progressRatio, closeTo(0.3, 0.001));
    });

    test('parses completed goal correctly', () {
      final json = {
        'id': 'xyz-789',
        'user_id': 'user_001',
        'title': 'Done',
        'target_amount': 50000,
        'deadline': null,
        'current_amount': 50000,
        'status': 'completed',
        'progress_percent': 100.0,
        'created_at': '2026-06-23T10:00:00',
        'updated_at': '2026-06-24T08:00:00',
      };

      final goal = Goal.fromJson(json);
      expect(goal.status, 'completed');
      expect(goal.isCompleted, true);
      expect(goal.isActive, false);
      expect(goal.isCancelled, false);
      expect(goal.progressPercent, 100.0);
      expect(goal.progressRatio, 1.0);
      expect(goal.deadline, isNull);
      expect(goal.isOverdue, false);
    });

    test('parses cancelled goal correctly', () {
      final json = {
        'id': 'cancel-1',
        'user_id': 'user_001',
        'title': 'Cancelled',
        'target_amount': 10000,
        'deadline': '2026-06-01',
        'current_amount': 2000,
        'status': 'cancelled',
        'progress_percent': 20.0,
        'created_at': '2026-05-01T00:00:00',
        'updated_at': '2026-06-01T00:00:00',
      };

      final goal = Goal.fromJson(json);
      expect(goal.status, 'cancelled');
      expect(goal.isCancelled, true);
      expect(goal.isActive, false);
      expect(goal.isCompleted, false);
      expect(goal.progressPercent, 20.0);
      expect(goal.progressRatio, 0.2);
    });
  });

  group('Goal.formatAmount', () {
    test('formats zero correctly', () {
      final goal = _defaultGoal();
      expect(goal.formatAmount(0), '¥0');
    });

    test('formats hundreds correctly', () {
      final goal = _defaultGoal();
      expect(goal.formatAmount(500), '¥500');
    });

    test('formats thousands with commas', () {
      final goal = _defaultGoal();
      expect(goal.formatAmount(50000), '¥50,000');
    });

    test('formats millions with commas', () {
      final goal = _defaultGoal();
      expect(goal.formatAmount(3000000), '¥3,000,000');
    });

    test('formats negative amounts', () {
      final goal = _defaultGoal();
      expect(goal.formatAmount(-1500), '-¥1,500');
    });
  });

  group('Goal.isOverdue', () {
    test('returns false when deadline is null', () {
      final goal = _defaultGoal().copyWith(deadline: null);
      expect(goal.isOverdue, false);
    });

    test('returns true when deadline is in the past and goal is active', () {
      final goal = _defaultGoal().copyWith(
        deadline: '2020-01-01',
        status: 'active',
      );
      expect(goal.isOverdue, true);
    });

    test('returns false when deadline is in the past but goal is completed', () {
      final goal = _defaultGoal().copyWith(
        deadline: '2020-01-01',
        status: 'completed',
      );
      expect(goal.isOverdue, false);
    });

    test('returns false when deadline is in the future', () {
      final goal = _defaultGoal().copyWith(
        deadline: '2099-12-31',
        status: 'active',
      );
      expect(goal.isOverdue, false);
    });
  });

  group('Goal status booleans', () {
    test('active goal has correct flags', () {
      final goal = _defaultGoal().copyWith(status: 'active');
      expect(goal.isActive, true);
      expect(goal.isCompleted, false);
      expect(goal.isCancelled, false);
    });

    test('completed goal has correct flags', () {
      final goal = _defaultGoal().copyWith(status: 'completed');
      expect(goal.isActive, false);
      expect(goal.isCompleted, true);
      expect(goal.isCancelled, false);
    });

    test('cancelled goal has correct flags', () {
      final goal = _defaultGoal().copyWith(status: 'cancelled');
      expect(goal.isActive, false);
      expect(goal.isCompleted, false);
      expect(goal.isCancelled, true);
    });
  });
}

Goal _defaultGoal() {
  return Goal(
    id: 'test-id',
    userId: 'user_001',
    title: 'Test',
    targetAmount: 100000,
    deadline: '2026-12-31',
    currentAmount: 0,
    status: 'active',
    progressPercent: 0.0,
    createdAt: DateTime(2026, 6, 24),
    updatedAt: DateTime(2026, 6, 24),
  );
}

extension _GoalCopyWith on Goal {
  Goal copyWith({
    String? id,
    String? userId,
    String? title,
    int? targetAmount,
    String? deadline,
    int? currentAmount,
    String? status,
    double? progressPercent,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Goal(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      targetAmount: targetAmount ?? this.targetAmount,
      deadline: deadline ?? this.deadline,
      currentAmount: currentAmount ?? this.currentAmount,
      status: status ?? this.status,
      progressPercent: progressPercent ?? this.progressPercent,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
