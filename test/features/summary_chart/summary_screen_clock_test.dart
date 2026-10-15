import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/domain/services/expense_repository.dart';
import 'package:kozuchi/features/summary_chart/presentation/screens/summary_screen.dart';

class _FakeExpenseRepository implements ExpenseRepository {
  _FakeExpenseRepository(this.entries);

  final List<ExpenseEntry> entries;

  @override
  Future<List<ExpenseEntry>> getEntries({
    required DateTime start,
    required DateTime end,
  }) async {
    return entries.where((e) {
      final day = DateTime(e.date.year, e.date.month, e.date.day);
      return !day.isBefore(DateTime(start.year, start.month, start.day)) &&
          !day.isAfter(DateTime(end.year, end.month, end.day));
    }).toList();
  }

  @override
  Future<void> saveEntry(ExpenseEntry entry) async {}

  @override
  Future<void> saveEntries(List<ExpenseEntry> entries) async {}

  @override
  Future<int> getEntryCount() async => entries.length;

  @override
  Future<void> clearAll() async {}

  @override
  Future<void> deleteEntry(String id) async =>
      entries.removeWhere((e) => e.id == id);

  @override
  Future<ExpenseEntry?> getEntryById(String id) async {
    for (final entry in entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }
}

/// WashiBackground が無限アニメーション（repeat）のため pumpAndSettle は使えない。
/// 固定 duration の pump で進める。
Future<void> _pump(WidgetTester tester, SummaryScreen screen) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MaterialApp(home: screen));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

DateTime _weekStart(DateTime date) {
  final dayOnly = DateTime(date.year, date.month, date.day);
  return dayOnly.subtract(Duration(days: dayOnly.weekday - 1));
}

String _formatRange(DateTime start, DateTime end) =>
    '${start.month}/${start.day} 〜 ${end.month}/${end.day}';

void main() {
  final fixedClock = () => DateTime(2026, 10, 15, 12);
  final repo = _FakeExpenseRepository([
    ExpenseEntry(
      id: 'e1',
      amount: 500,
      category: '食費',
      date: DateTime(2026, 9, 20),
    ),
    ExpenseEntry(
      id: 'e2',
      amount: 300,
      category: '日用品',
      date: DateTime(2026, 9, 30),
    ),
    ExpenseEntry(
      id: 'e3',
      amount: 200,
      category: '食費',
      date: DateTime(2026, 10, 5),
    ),
    ExpenseEntry(
      id: 'e4',
      amount: 800,
      category: '娯楽',
      date: DateTime(2026, 10, 14),
    ),
  ]);

  bool nextEnabled(WidgetTester tester) =>
      tester.widget<IconButton>(find.byKey(const Key('nav_next')))
          .onPressed !=
      null;

  testWidgets('clock を注入すると初期基準日が注入日付になる（週間）', (tester) async {
    await _pump(
      tester,
      SummaryScreen(repository: repo, clock: fixedClock),
    );

    // 2026-10-15（木）を含む週（月曜始まり）が表示されること
    final expectedStart = _weekStart(DateTime(2026, 10, 15, 12));
    final expectedEnd = expectedStart.add(const Duration(days: 6));
    expect(
      find.text(_formatRange(expectedStart, expectedEnd)),
      findsOneWidget,
    );

    // 実行時刻ではなく注入日付が使われたことの決定論的裏付け:
    // 別の注入日付（10/1 の週）では別の範囲が表示される
  });

  testWidgets('別の注入日付では別の週が表示される（決定論の裏付け）', (tester) async {
    await _pump(
      tester,
      SummaryScreen(
        repository: repo,
        clock: () => DateTime(2026, 10, 1, 12),
      ),
    );
    final altStart = _weekStart(DateTime(2026, 10, 1, 12));
    expect(
      find.text(_formatRange(altStart, altStart.add(const Duration(days: 6)))),
      findsOneWidget,
    );
  });

  testWidgets('当週では「次へ」が無効で、前へ移動後に次へで戻れる（週間）', (tester) async {
    await _pump(
      tester,
      SummaryScreen(repository: repo, clock: fixedClock),
    );

    // 当週: 次へは無効
    expect(nextEnabled(tester), isFalse);

    // 前へで過去週へ移動
    await tester.tap(find.byKey(const Key('nav_previous')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));


    final prevStart =
        _weekStart(DateTime(2026, 10, 15, 12)).subtract(const Duration(days: 7));
    expect(
      find.text(_formatRange(prevStart, prevStart.add(const Duration(days: 6)))),
      findsOneWidget,
    );

    // 過去週では次へが有効
    expect(nextEnabled(tester), isTrue);

    // 次へで当週へ戻る
    await tester.tap(find.byKey(const Key('nav_next')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final curStart = _weekStart(DateTime(2026, 10, 15, 12));
    expect(
      find.text(_formatRange(curStart, curStart.add(const Duration(days: 6)))),
      findsOneWidget,
    );
    expect(nextEnabled(tester), isFalse);
  });

  testWidgets('当月では「次へ」が無効で、前へ移動後に次へで戻れる（月間）', (tester) async {
    await _pump(
      tester,
      SummaryScreen(repository: repo, clock: fixedClock),
    );

    // 月間モードへ切替
    await tester.tap(find.text('月間'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 当月: 次へは無効
    expect(nextEnabled(tester), isFalse);

    // 前へで前月へ移動（2026年10月 → 2026年9月）
    await tester.tap(find.byKey(const Key('nav_previous')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('9/1 〜 9/30'), findsOneWidget);
    expect(nextEnabled(tester), isTrue);

    // 次へで当月へ戻る
    await tester.tap(find.byKey(const Key('nav_next')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('10/1 〜 10/31'), findsOneWidget);
    expect(nextEnabled(tester), isFalse);
  });

  testWidgets('clock 未注入（既定）でも画面は従来どおり構築される', (tester) async {
    await _pump(tester, SummaryScreen(repository: repo));
    // 既定（clock 未指定）では実時計が使われ、当週データがあれば
    // ナビゲーションが表示され次へは無効（従来挙動）。
    if (find.byKey(const Key('date_navigation')).evaluate().isNotEmpty) {
      expect(nextEnabled(tester), isFalse);
    } else {
      // 実行時の実週にデータが無い場合は空状態が表示される（従来挙動）
      expect(find.byKey(const Key('summary_empty')), findsOneWidget);
    }
  });
}
