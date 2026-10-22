import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kozuchi/features/weekly_quest/data/shared_preferences_weekly_quest_store.dart';
import 'package:kozuchi/features/weekly_quest/data/weekly_quest_store.dart';
import 'package:kozuchi/features/weekly_quest/domain/models/active_weekly_quest.dart';
import 'package:kozuchi/features/weekly_quest/domain/models/weekly_quest.dart';
import 'package:kozuchi/features/weekly_quest/domain/models/weekly_quest_state.dart';

DateTime day(int year, int month, int dayOfMonth) =>
    DateTime(year, month, dayOfMonth);

WeeklyQuest quest({String id = 'q1'}) {
  return WeeklyQuest(
    id: id,
    title: '今週は食費を¥8,000以内に',
    description: '節約しよう',
    targetCategory: '食費',
    budgetLimit: 8000,
    currentAvgSpend: 10000,
    difficulty: QuestDifficulty.medium,
    generatedAt: day(2026, 10, 19),
    weekStart: day(2026, 10, 19),
    templateId: 'budgetLimit',
  );
}

WeeklyQuestState sampleState() {
  return WeeklyQuestState(
    weekKey: '2026-10-19',
    pending: [quest(id: 'a'), quest(id: 'b')],
    active: ActiveWeeklyQuest(
      quest: quest(id: 'c'),
      status: WeeklyQuestStatus.active,
      selectedAt: day(2026, 10, 20),
    ),
    generatedAt: day(2026, 10, 19),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InMemoryWeeklyQuestStore', () {
    test('未保存は null', () async {
      final store = InMemoryWeeklyQuestStore();
      expect(await store.load(), isNull);
    });

    test('save した内容が load で返る', () async {
      final store = InMemoryWeeklyQuestStore();
      final state = sampleState();
      await store.save(state);
      expect(store.stored, state);
      expect(await store.load(), state);
    });

    test('clear で null に戻る', () async {
      final store = InMemoryWeeklyQuestStore();
      await store.save(sampleState());
      await store.clear();
      expect(store.stored, isNull);
      expect(await store.load(), isNull);
    });
  });

  group('SharedPreferencesWeeklyQuestStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('storageKey は v1 キー', () {
      expect(
        SharedPreferencesWeeklyQuestStore.storageKey,
        'weekly_quest_state_v1',
      );
    });

    test('未保存は null', () async {
      const store = SharedPreferencesWeeklyQuestStore();
      expect(await store.load(), isNull);
    });

    test('save → load で往復する', () async {
      const store = SharedPreferencesWeeklyQuestStore();
      final state = sampleState();
      await store.save(state);

      final restored = await store.load();
      expect(restored, isNotNull);
      expect(restored!.weekKey, state.weekKey);
      expect(restored.pending.map((q) => q.id), ['a', 'b']);
      expect(restored.active?.quest.id, 'c');
      expect(restored.active?.status, WeeklyQuestStatus.active);
      expect(restored.generatedAt, state.generatedAt);
    });

    test('生の保存値は JSON 文字列（jsonDecode 可能）', () async {
      const store = SharedPreferencesWeeklyQuestStore();
      await store.save(sampleState());
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(SharedPreferencesWeeklyQuestStore.storageKey);
      expect(raw, isNotNull);
      final decoded = jsonDecode(raw!);
      expect(decoded, isA<Map<String, dynamic>>());
      expect((decoded as Map)['weekKey'], '2026-10-19');
    });

    test('空文字は null', () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesWeeklyQuestStore.storageKey: '',
      });
      const store = SharedPreferencesWeeklyQuestStore();
      expect(await store.load(), isNull);
    });

    test('JSON 破損は null（例外を投げない）', () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesWeeklyQuestStore.storageKey: '{not json',
      });
      const store = SharedPreferencesWeeklyQuestStore();
      expect(await store.load(), isNull);
    });

    test('型不一致（JSON 配列）は null', () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesWeeklyQuestStore.storageKey: '[1,2,3]',
      });
      const store = SharedPreferencesWeeklyQuestStore();
      expect(await store.load(), isNull);
    });

    test('型不一致（int 保存）は null', () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesWeeklyQuestStore.storageKey: 42,
      });
      const store = SharedPreferencesWeeklyQuestStore();
      expect(await store.load(), isNull);
    });

    test('壊れた要素は読み飛ばして生存要素を返す', () async {
      final broken = jsonEncode(<String, dynamic>{
        'weekKey': '2026-10-19',
        'generatedAt': '2026-10-19T00:00:00.000',
        'pending': [
          quest(id: 'ok').toJson(),
          {'id': 1},
        ],
        'active': 'oops',
      });
      SharedPreferences.setMockInitialValues({
        SharedPreferencesWeeklyQuestStore.storageKey: broken,
      });
      const store = SharedPreferencesWeeklyQuestStore();
      final loaded = await store.load();
      expect(loaded, isNotNull);
      expect(loaded!.pending.map((q) => q.id), ['ok']);
      expect(loaded.active, isNull);
    });

    test('clear で削除され null に戻る', () async {
      const store = SharedPreferencesWeeklyQuestStore();
      await store.save(sampleState());
      await store.clear();
      expect(await store.load(), isNull);
    });

    test('上書き保存は最新のみ残る', () async {
      const store = SharedPreferencesWeeklyQuestStore();
      await store.save(sampleState());
      await store.save(
        WeeklyQuestState(
          weekKey: '2026-10-26',
          pending: [quest(id: 'z')],
          generatedAt: day(2026, 10, 26),
        ),
      );
      final loaded = await store.load();
      expect(loaded!.weekKey, '2026-10-26');
      expect(loaded.pending.map((q) => q.id), ['z']);
      expect(loaded.active, isNull);
    });
  });
}
