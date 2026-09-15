import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/domain/services/expense_repository.dart';
import 'package:kozuchi/features/monthly_report/presentation/screens/monthly_report_screen.dart';
import 'package:kozuchi/features/shared/presentation/kozuchi_app_keys.dart';
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
}

/// WashiBackground が無限アニメーション（repeat）のため pumpAndSettle は使えない。
/// 固定 duration の pump で進める。
Future<void> _pumpSummary(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: SummaryScreen(repository: _FakeExpenseRepository(const [])),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('支出サマリー画面からの月次レポート導線', () {
    testWidgets('AppBar に月次レポートの導線ボタンがある', (tester) async {
      await _pumpSummary(tester);
      expect(find.byKey(KozuchiAppKeys.monthlyReportEntry), findsOneWidget);
    });

    testWidgets('タップで MonthlyReportScreen に遷移する', (tester) async {
      await _pumpSummary(tester);

      await tester.tap(find.byKey(KozuchiAppKeys.monthlyReportEntry));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(MonthlyReportScreen), findsOneWidget);
      expect(find.byKey(KozuchiAppKeys.monthlyReportCard), findsOneWidget);
    });
  });
}
