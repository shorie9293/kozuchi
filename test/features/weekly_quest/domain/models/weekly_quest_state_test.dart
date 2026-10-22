import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/weekly_quest/domain/models/active_weekly_quest.dart';
import 'package:kozuchi/features/weekly_quest/domain/models/weekly_quest.dart';
import 'package:kozuchi/features/weekly_quest/domain/models/weekly_quest_state.dart';

DateTime day(int year, int month, int dayOfMonth) =>
    DateTime(year, month, dayOfMonth);

WeeklyQuest quest({String id = 'q1', String targetCategory = '食費'}) {
  return WeeklyQuest(
    id: id,
    title: '今週は$targetCategoryを¥8,000以内に',
    description: '節約しよう',
    targetCategory: targetCategory,
    budgetLimit: 8000,
    currentAvgSpend: 10000,
    difficulty: QuestDifficulty.medium,
    generatedAt: day(2026, 10, 19),
    weekStart: day(2026, 10, 19),
    templateId: 'budgetLimit',
  );
}

void main() {
  group('生成と getter', () {
    test('空状態', () {
      final state = WeeklyQuestState(
        weekKey: '2026-10-19',
        pending: const [],
        generatedAt: day(2026, 10, 19),
      );
      expect(state.hasPending, isFalse);
      expect(state.isActive, isFalse);
      expect(state.isEmpty, isTrue);
    });

    test('pending があれば hasPending', () {
      final state = WeeklyQuestState(
        weekKey: '2026-10-19',
        pending: [quest(id: 'a'), quest(id: 'b')],
        generatedAt: day(2026, 10, 19),
      );
      expect(state.hasPending, isTrue);
      expect(state.isEmpty, isFalse);
      expect(state.isActive, isFalse);
    });

    test('active があれば isActive / isEmpty は false', () {
      final state = WeeklyQuestState(
        weekKey: '2026-10-19',
        pending: const [],
        active: ActiveWeeklyQuest(
          quest: quest(),
          status: WeeklyQuestStatus.active,
          selectedAt: day(2026, 10, 20),
        ),
        generatedAt: day(2026, 10, 19),
      );
      expect(state.isActive, isTrue);
      expect(state.isEmpty, isFalse);
    });
  });

  group('copyWith', () {
    final base = WeeklyQuestState(
      weekKey: '2026-10-19',
      pending: [quest(id: 'a'), quest(id: 'b')],
      generatedAt: day(2026, 10, 19),
    );

    test('未指定フィールドは維持される', () {
      final next = base.copyWith();
      expect(next.weekKey, base.weekKey);
      expect(next.pending.length, 2);
      expect(next.generatedAt, base.generatedAt);
      expect(next.active, isNull);
    });

    test('pending を差し替えられる', () {
      final next = base.copyWith(pending: [quest(id: 'b')]);
      expect(next.pending.map((q) => q.id), ['b']);
    });

    test('active を設定できる', () {
      final active = ActiveWeeklyQuest(
        quest: quest(id: 'a'),
        status: WeeklyQuestStatus.active,
        selectedAt: day(2026, 10, 20),
      );
      final next = base.copyWith(active: active);
      expect(next.active, active);
    });

    test('clearActive で active を null に戻せる', () {
      final withActive = base.copyWith(
        active: ActiveWeeklyQuest(
          quest: quest(id: 'a'),
          status: WeeklyQuestStatus.active,
        ),
      );
      final cleared = withActive.copyWith(clearActive: true);
      expect(cleared.active, isNull);
    });
  });

  group('JSON 往復', () {
    test('pending と active が復元される', () {
      final active = ActiveWeeklyQuest(
        quest: quest(id: 'a'),
        status: WeeklyQuestStatus.active,
        selectedAt: day(2026, 10, 20),
      );
      final state = WeeklyQuestState(
        weekKey: '2026-10-19',
        pending: [quest(id: 'b'), quest(id: 'c')],
        active: active,
        generatedAt: day(2026, 10, 19),
      );
      final restored = WeeklyQuestState.fromJson(state.toJson());
      expect(restored.weekKey, '2026-10-19');
      expect(restored.pending.map((q) => q.id), ['b', 'c']);
      expect(restored.active?.quest.id, 'a');
      expect(restored.active?.status, WeeklyQuestStatus.active);
      expect(restored.generatedAt, day(2026, 10, 19));
    });

    test('active が無い場合も往復できる', () {
      final state = WeeklyQuestState(
        weekKey: '2026-10-19',
        pending: [quest(id: 'b')],
        generatedAt: day(2026, 10, 19),
      );
      final json = state.toJson();
      expect(json.containsKey('active'), isFalse);
      final restored = WeeklyQuestState.fromJson(json);
      expect(restored.active, isNull);
      expect(restored.pending.length, 1);
    });

    test('空状態も往復できる', () {
      final state = WeeklyQuestState(
        weekKey: '2026-10-19',
        pending: const [],
        generatedAt: day(2026, 10, 19),
      );
      final restored = WeeklyQuestState.fromJson(state.toJson());
      expect(restored.isEmpty, isTrue);
    });
  });

  group('fromJson: 破損要素の読み飛ばし', () {
    test('壊れた pending 要素だけ捨てる', () {
      final json = <String, dynamic>{
        'weekKey': '2026-10-19',
        'generatedAt': '2026-10-19T00:00:00.000',
        'pending': [
          quest(id: 'ok1').toJson(),
          {'id': 123}, // 型不一致
          {'title': 'id がない'}, // 欠損
          'not-a-map',
          quest(id: 'ok2').toJson(),
        ],
      };
      final restored = WeeklyQuestState.fromJson(json);
      expect(restored.pending.map((q) => q.id), ['ok1', 'ok2']);
    });

    test('pending が List でなければ空', () {
      final restored = WeeklyQuestState.fromJson(<String, dynamic>{
        'weekKey': '2026-10-19',
        'generatedAt': '2026-10-19T00:00:00.000',
        'pending': 'broken',
      });
      expect(restored.pending, isEmpty);
    });

    test('壊れた active は null に落とす（pending は保つ）', () {
      final restored = WeeklyQuestState.fromJson(<String, dynamic>{
        'weekKey': '2026-10-19',
        'generatedAt': '2026-10-19T00:00:00.000',
        'pending': [quest(id: 'ok1').toJson()],
        'active': {'status': 'active'},
      });
      expect(restored.active, isNull);
      expect(restored.pending.length, 1);
    });

    test('generatedAt 不正でも例外にせずエポックへ倒す', () {
      final restored = WeeklyQuestState.fromJson(<String, dynamic>{
        'weekKey': '2026-10-19',
        'generatedAt': 'not-a-date',
        'pending': const [],
      });
      expect(restored.generatedAt.millisecondsSinceEpoch, 0);
    });

    test('weekKey 不正でも例外にしない', () {
      final restored = WeeklyQuestState.fromJson(<String, dynamic>{
        'weekKey': 42,
        'pending': const [],
      });
      expect(restored.weekKey, '');
    });
  });

  group('等価性', () {
    test('同じ内容なら等しい', () {
      final a = WeeklyQuestState(
        weekKey: '2026-10-19',
        pending: [quest(id: 'a')],
        generatedAt: day(2026, 10, 19),
      );
      final b = WeeklyQuestState(
        weekKey: '2026-10-19',
        pending: [quest(id: 'a')],
        generatedAt: day(2026, 10, 19),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('weekKey が違えば等しくない', () {
      final a = WeeklyQuestState(
        weekKey: '2026-10-19',
        pending: const [],
        generatedAt: day(2026, 10, 19),
      );
      final b = WeeklyQuestState(
        weekKey: '2026-10-26',
        pending: const [],
        generatedAt: day(2026, 10, 19),
      );
      expect(a == b, isFalse);
    });

    test('pending の要素が違えば等しくない', () {
      final a = WeeklyQuestState(
        weekKey: '2026-10-19',
        pending: [quest(id: 'a')],
        generatedAt: day(2026, 10, 19),
      );
      final b = WeeklyQuestState(
        weekKey: '2026-10-19',
        pending: [quest(id: 'b')],
        generatedAt: day(2026, 10, 19),
      );
      expect(a == b, isFalse);
    });
  });
}
