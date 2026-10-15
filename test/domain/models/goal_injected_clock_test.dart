import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/goal.dart';

void main() {
  final deadline = DateTime(2026, 10, 20);
  Goal goal({DateTime? dl, GoalStatus status = GoalStatus.active}) => Goal(
        id: 'g1',
        title: 'テスト目標',
        deadline: dl,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        status: status,
      );

  group('Goal.isOverdueAt（固定 now）', () {
    test('期限ちょうどの now では期限切れでない', () {
      expect(goal(dl: deadline).isOverdueAt(deadline), isFalse);
    });

    test('期限前日では期限切れでない', () {
      expect(
        goal(dl: deadline).isOverdueAt(DateTime(2026, 10, 19)),
        isFalse,
      );
    });

    test('期限翌日では期限切れ', () {
      expect(
        goal(dl: deadline).isOverdueAt(DateTime(2026, 10, 21)),
        isTrue,
      );
    });

    test('無期限では常に期限切れでない', () {
      expect(goal().isOverdueAt(DateTime(2030, 1, 1)), isFalse);
    });

    test('status が completed なら期限過ぎでも期限切れでない', () {
      expect(
        goal(dl: deadline, status: GoalStatus.completed)
            .isOverdueAt(DateTime(2026, 10, 21)),
        isFalse,
      );
    });

    test('既定 getter は実時計に委譲している（従来挙動: 過去期限+active なら true）', () {
      final past = goal(dl: DateTime(2000, 1, 1));
      expect(past.isOverdue, isTrue);
      expect(past.isOverdueAt(past.deadline!), isFalse);
    });
  });

  group('Goal.remainingDaysFrom（固定 now）', () {
    test('期限前日なら残り1日', () {
      expect(
        goal(dl: deadline).remainingDaysFrom(DateTime(2026, 10, 19)),
        1,
      );
    });

    test('期限ちょうどなら0日', () {
      expect(goal(dl: deadline).remainingDaysFrom(deadline), 0);
    });

    test('期限翌日なら負の値', () {
      expect(
        goal(dl: deadline).remainingDaysFrom(DateTime(2026, 10, 21)),
        -1,
      );
    });

    test('無期限なら null', () {
      expect(goal().remainingDaysFrom(DateTime(2026, 10, 15)), isNull);
    });

    test('既定 getter は実時計に委譲している（期限未来なら正、シグネチャ不変）', () {
      final future = goal(dl: DateTime(2999, 1, 1));
      expect(future.remainingDays, isPositive);
      expect(future.remainingDaysFrom(DateTime(2998, 1, 1))! > 0, isTrue);
    });
  });
}
