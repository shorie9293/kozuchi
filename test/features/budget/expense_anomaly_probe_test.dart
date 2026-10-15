import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/domain/services/expense_repository.dart';
import 'package:kozuchi/domain/services/expense_repository_impl.dart';
import 'package:kozuchi/features/budget/domain/expense_anomaly.dart';
import 'package:kozuchi/features/budget/domain/expense_anomaly_service.dart';
import 'package:kozuchi/features/budget/presentation/expense_anomaly_app_keys.dart';
import 'package:kozuchi/features/budget/presentation/screens/expense_anomaly_screen.dart';

/// 親探針: 眷属が個別にしか撃たない「合成の不変条件」を独立に検証する。
/// 親探針はバグ発見だけでなく『実バグなし』の確証にも使う。

final DateTime _now = DateTime(2026, 10, 16, 12);

/// getEntries に渡された引数を捕捉するスパイ・リポジトリ
class _SpyExpenseRepository implements ExpenseRepository {
  _SpyExpenseRepository(this._entries);

  final List<ExpenseEntry> _entries;
  DateTime? capturedStart;
  DateTime? capturedEnd;

  @override
  Future<List<ExpenseEntry>> getEntries({
    required DateTime start,
    required DateTime end,
  }) async {
    capturedStart = start;
    capturedEnd = end;
    return _entries
        .where((e) => !e.date.isBefore(start) && !e.date.isAfter(end))
        .toList();
  }

  @override
  Future<void> saveEntry(ExpenseEntry entry) async {}
  @override
  Future<void> saveEntries(List<ExpenseEntry> entries) async {}
  @override
  Future<int> getEntryCount() async => _entries.length;
  @override
  Future<void> clearAll() async {}
  @override
  Future<void> deleteEntry(String id) async {}
  @override
  Future<ExpenseEntry?> getEntryById(String id) async =>
      _entries.where((e) => e.id == id).firstOrNull;
}

void main() {
  group('親探針: ExpenseAnomalyScreen 合成の不変条件', () {
    testWidgets('P1 画面の表示件数が service の detectAll 結果件数と厳密一致する',
        (tester) async {
      // 食費: 通常4件(1000) + 異常2件(3000, 4000) / 交通費: 通常だけ
      final entries = <ExpenseEntry>[
        for (var i = 1; i <= 4; i++)
          ExpenseEntry(
              id: 'f$i',
              amount: 1000,
              category: '食費',
              date: DateTime(2026, 10, i, 10)),
        ExpenseEntry(
            id: 'fA',
            amount: 3000,
            category: '食費',
            date: DateTime(2026, 10, 5, 10)),
        ExpenseEntry(
            id: 'fB',
            amount: 4000,
            category: '食費',
            date: DateTime(2026, 10, 6, 10)),
        for (var i = 1; i <= 4; i++)
          ExpenseEntry(
              id: 't$i',
              amount: 500,
              category: '交通費',
              date: DateTime(2026, 10, i, 9)),
      ];
      final expected = const ExpenseAnomalyService().detectAll(entries);

      final repo = InMemoryExpenseRepository();
      await repo.saveEntries(entries);

      await tester.pumpWidget(MaterialApp(
        home: ExpenseAnomalyScreen(repository: repo, now: () => _now),
      ));
      await tester.pumpAndSettle();

      // 画面に現れる異常行のキー数 == service の件数
      final rowFinder = find.byWidgetPredicate((w) =>
          w.key is ValueKey<String> &&
          (w.key as ValueKey<String>).value.startsWith('expenseAnomaly_row_'));
      expect(rowFinder, findsNWidgets(expected.length));
      expect(expected.length, greaterThan(0));

      // サマリーの件数表記も一致
      expect(
        find.descendant(
          of: find.byKey(ExpenseAnomalyAppKeys.summary),
          matching: find.textContaining('検知件数 ${expected.length}件'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('P2 ルックバック窓を repository へ正しく渡す(now 注入で固定)',
        (tester) async {
      final spy = _SpyExpenseRepository(const []);
      await tester.pumpWidget(MaterialApp(
        home: ExpenseAnomalyScreen(
            repository: spy, now: () => _now, lookbackDays: 30),
      ));
      await tester.pumpAndSettle();

      expect(spy.capturedEnd, _now);
      expect(spy.capturedStart, _now.subtract(const Duration(days: 30)));
    });

    testWidgets('P3 サンプル数不足は高額でも誤検知しない(フォールバック)',
        (tester) async {
      // 食費の同カテゴリ履歴が minSamples(3) 未満 → 10倍でも検知しない
      final entries = <ExpenseEntry>[
        ExpenseEntry(
            id: 'a',
            amount: 1000,
            category: '食費',
            date: DateTime(2026, 10, 1, 10)),
        ExpenseEntry(
            id: 'b',
            amount: 1000,
            category: '食費',
            date: DateTime(2026, 10, 2, 10)),
        ExpenseEntry(
            id: 'c',
            amount: 10000,
            category: '食費',
            date: DateTime(2026, 10, 3, 10)),
      ];
      final repo = InMemoryExpenseRepository();
      await repo.saveEntries(entries);

      await tester.pumpWidget(MaterialApp(
        home: ExpenseAnomalyScreen(repository: repo, now: () => _now),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(ExpenseAnomalyAppKeys.empty), findsOneWidget);
    });

    testWidgets('P4 しきい値ちょうど2.0倍は elevated として表示される',
        (tester) async {
      // 履歴4件 1000 平均1000、候補 2000 → ratio ちょうど 2.0
      final entries = <ExpenseEntry>[
        for (var i = 1; i <= 4; i++)
          ExpenseEntry(
              id: 'h$i',
              amount: 1000,
              category: '食費',
              date: DateTime(2026, 10, i, 10)),
        ExpenseEntry(
            id: 'edge',
            amount: 2000,
            category: '食費',
            date: DateTime(2026, 10, 8, 10)),
      ];
      final repo = InMemoryExpenseRepository();
      await repo.saveEntries(entries);

      await tester.pumpWidget(MaterialApp(
        home: ExpenseAnomalyScreen(repository: repo, now: () => _now),
      ));
      await tester.pumpAndSettle();

      final row = find.byKey(const ValueKey<String>('expenseAnomaly_row_edge'));
      expect(row, findsOneWidget);
      expect(
        find.descendant(of: row, matching: find.text(AnomalyLevel.elevated.label)),
        findsOneWidget,
      );
    });
  });
}
