import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/goals/data/goal.dart';

void main() {
  Goal goal({String? deadline, String status = 'active'}) => Goal(
        id: 'g1',
        userId: 'default',
        title: 'テスト目標',
        targetAmount: 10000,
        deadline: deadline,
        currentAmount: 0,
        status: status,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

  group('data Goal.isOverdueAt（固定 now）', () {
    test('期限ちょうどの now では期限切れでない', () {
      expect(
        goal(deadline: '2026-10-20').isOverdueAt(DateTime(2026, 10, 20)),
        isFalse,
      );
    });

    test('期限前日では期限切れでない', () {
      expect(
        goal(deadline: '2026-10-20').isOverdueAt(DateTime(2026, 10, 19, 12)),
        isFalse,
      );
    });

    test('期限翌日では期限切れ', () {
      expect(
        goal(deadline: '2026-10-20').isOverdueAt(DateTime(2026, 10, 21, 12)),
        isTrue,
      );
    });

    test('無期限では常に期限切れでない', () {
      expect(goal().isOverdueAt(DateTime(2030, 1, 1)), isFalse);
    });

    test('期限文字列が不正なら期限切れでない', () {
      expect(
        goal(deadline: 'not-a-date').isOverdueAt(DateTime(2030, 1, 1)),
        isFalse,
      );
    });

    test('status が completed / cancelled なら期限過ぎでも期限切れでない', () {
      expect(
        goal(deadline: '2026-10-20', status: 'completed')
            .isOverdueAt(DateTime(2026, 10, 21, 12)),
        isFalse,
      );
      expect(
        goal(deadline: '2026-10-20', status: 'cancelled')
            .isOverdueAt(DateTime(2026, 10, 21, 12)),
        isFalse,
      );
    });

    test('既定 getter は実時計に委譲している（従来挙動: 過去期限+active なら true）', () {
      expect(goal(deadline: '2000-01-01').isOverdue, isTrue);
    });
  });
}
