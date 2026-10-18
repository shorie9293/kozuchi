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

/// WashiBackground が無限アニメーションのため pumpAndSettle は使わない。
Future<void> _pump(WidgetTester tester, SummaryScreen screen) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MaterialApp(home: screen));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _switchToMonthly(WidgetTester tester) async {
  await tester.tap(find.text('月間'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

ExpenseEntry _entry(String id, int amount, DateTime date) => ExpenseEntry(
      id: id,
      amount: amount,
      category: '食費',
      date: date,
    );

void main() {
  // now は UTC 由来で構築（TZ=UTC でも緑）。
  DateTime clockDate() => DateTime.utc(2026, 11, 1, 12).toLocal();

  // 締め日25 の境界を跨ぐエントリ群。
  final entries = [
    _entry('e-10-24', 100, DateTime.utc(2026, 10, 24, 12).toLocal()),
    _entry('e-10-25', 200, DateTime.utc(2026, 10, 25, 12).toLocal()),
    _entry('e-10-26', 400, DateTime.utc(2026, 10, 26, 12).toLocal()),
    _entry('e-11-26', 800, DateTime.utc(2026, 11, 26, 12).toLocal()),
  ];

  testWidgets('closingDayLoader=25 が集計まで貫通する（10/26〜11/25 のみ）', (tester) async {
    await _pump(
      tester,
      SummaryScreen(
        repository: _FakeExpenseRepository(entries),
        clock: clockDate,
        closingDayLoader: () async => 25,
      ),
    );
    await _switchToMonthly(tester);

    // 期間は 2026/10/26 〜 2026/11/25
    expect(find.text('10/26 〜 11/25'), findsOneWidget);

    // 当期合計は 10/26 の 400 のみ（10/25 も入ると 600、11/26 も入ると 1200）
    expect(find.text('¥400'), findsWidgets);
    expect(find.text('¥600'), findsNothing);
    expect(find.text('¥1200'), findsNothing);
  });

  testWidgets('closingDayLoader=25 で 10/25 を含む期間では 10/26 が入らない', (tester) async {
    await _pump(
      tester,
      SummaryScreen(
        repository: _FakeExpenseRepository(entries),
        clock: () => DateTime.utc(2026, 10, 20, 12).toLocal(),
        closingDayLoader: () async => 25,
      ),
    );
    await _switchToMonthly(tester);

    // 2026/09/26 〜 2026/10/25
    expect(find.text('9/26 〜 10/25'), findsOneWidget);
    // 当期合計は 10/24 + 10/25 = 300（10/26 が入ると 700）
    expect(find.text('¥300'), findsWidgets);
    expect(find.text('¥700'), findsNothing);
  });

  testWidgets('closingDayLoader=null なら従来どおり暦月で集計する（回帰）', (tester) async {
    await _pump(
      tester,
      SummaryScreen(
        repository: _FakeExpenseRepository(entries),
        clock: clockDate,
      ),
    );
    await _switchToMonthly(tester);

    // 2026/11/01 〜 2026/11/30（従来挙動）
    expect(find.text('11/1 〜 11/30'), findsOneWidget);
    // 当月合計は 11/26 の 800 のみ
    expect(find.text('¥800'), findsWidgets);
  });

  testWidgets('closingDayLoader の読み込み失敗時も画面は壊れない（1 に倒れる）', (tester) async {
    await _pump(
      tester,
      SummaryScreen(
        repository: _FakeExpenseRepository(entries),
        clock: clockDate,
        closingDayLoader: () async => throw StateError('読み込み失敗'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    // 例外は画面全体を落とさない（従来の暦月表示 or 空状態）
    expect(find.byKey(const Key('summary_screen')), findsOneWidget);
  });
}
