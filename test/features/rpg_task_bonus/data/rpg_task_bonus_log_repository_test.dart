import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/features/rpg_task_bonus/data/rpg_task_bonus_log_repository.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RpgTaskBonusLogRepository', () {
    test('getTodayCount returns 0 initially', () async {
      final repo = RpgTaskBonusLogRepository();
      final count = await repo.getTodayCount();
      expect(count, 0);
    });

    test('recordBonus increments daily count', () async {
      final repo = RpgTaskBonusLogRepository();
      await repo.recordBonus(
        taskTitle: 'Test Quest',
        questRank: 'A',
        bonusExp: 30,
        baseExp: 100,
      );

      final count = await repo.getTodayCount();
      expect(count, 1);
    });

    test('recordBonus adds to log', () async {
      final repo = RpgTaskBonusLogRepository();
      await repo.recordBonus(
        taskTitle: '魔王討伐',
        questRank: 'S',
        bonusExp: 50,
        baseExp: 200,
      );

      final log = await repo.getLog();
      expect(log.length, 1);
      expect(log[0]['taskTitle'], '魔王討伐');
      expect(log[0]['questRank'], 'S');
      expect(log[0]['bonusExp'], 50);
      expect(log[0]['baseExp'], 200);
      expect(log[0]['timestamp'], isNotNull);
    });

    test('getLog returns empty list when no log exists', () async {
      final repo = RpgTaskBonusLogRepository();
      final log = await repo.getLog();
      expect(log, isEmpty);
    });

    test('Log maintains max 10 entries', () async {
      final repo = RpgTaskBonusLogRepository();
      for (int i = 0; i < 15; i++) {
        await repo.recordBonus(
          taskTitle: 'Quest $i',
          questRank: 'B',
          bonusExp: 15,
          baseExp: 50,
        );
      }

      final log = await repo.getLog();
      expect(log.length, 10);
      // 最新が先頭
      expect(log[0]['taskTitle'], 'Quest 14');
    });

    test('getRemainingBonusesToday returns correct remaining', () async {
      final repo = RpgTaskBonusLogRepository();
      await repo.recordBonus(
        taskTitle: 'Q1',
        questRank: 'B',
        bonusExp: 15,
        baseExp: 50,
      );

      final remaining = await repo.getRemainingBonusesToday(maxDaily: 3);
      expect(remaining, 2);
    });

    test('getRemainingBonusesToday returns 0 when at limit', () async {
      final repo = RpgTaskBonusLogRepository();
      for (int i = 0; i < 3; i++) {
        await repo.recordBonus(
          taskTitle: 'Q$i',
          questRank: 'B',
          bonusExp: 15,
          baseExp: 50,
        );
      }

      final remaining = await repo.getRemainingBonusesToday(maxDaily: 3);
      expect(remaining, 0);
    });
  });
}
