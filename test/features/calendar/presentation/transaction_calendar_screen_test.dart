import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/calendar/presentation/calendar_app_keys.dart';
import 'package:kozuchi/features/calendar/presentation/transaction_calendar_screen.dart';
import 'package:kozuchi/features/transaction_history/data/transaction_service.dart';
import 'package:kozuchi/features/transaction_history/presentation/screens/transaction_history_page.dart';
import 'package:kozuchi/features/transaction_history/presentation/state/transaction_controller.dart';
import 'package:kozuchi/features/tags/presentation/tag_app_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// テスト用のモックTransactionController（既存テストと同様の手法）。
class MockTransactionController extends TransactionController {
  final List<TransactionModel> _mockTransactions;

  MockTransactionController({List<TransactionModel> transactions = const []})
      : _mockTransactions = transactions,
        super(
          service: TransactionService(client: MockClient((_) async {
            return http.Response('{"data": []}', 200);
          })),
        );

  @override
  List<TransactionModel> get transactions => List.unmodifiable(_mockTransactions);

  @override
  Future<void> fetchTransactions() async {}

  @override
  Future<void> refetch() async {}
}

ExpenseEntry _entry({
  String id = 'e1',
  int amount = 1000,
  String category = '食費',
  DateTime? date,
  String? note,
}) =>
    ExpenseEntry(
      id: id,
      amount: amount,
      category: category,
      date: date ?? DateTime(2026, 9, 10),
      note: note,
    );

void main() {
  DateTime fixedClock() => DateTime(2026, 9, 15, 12, 0);

  Future<void> pumpScreen(
    WidgetTester tester, {
    List<ExpenseEntry>? entries,
    int? year,
    int? month,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TransactionCalendarScreen(
          entriesOverride: entries,
          clock: fixedClock,
          initialYear: year,
          initialMonth: month,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('月ラベルが指定年月を表示する', (tester) async {
    await pumpScreen(tester, year: 2026, month: 9);

    expect(find.byKey(CalendarAppKeys.monthLabel), findsOneWidget);
    expect(find.text('2026年9月'), findsOneWidget);
  });

  testWidgets('月合計が entries の合計と一致する', (tester) async {
    await pumpScreen(
      tester,
      entries: [
        _entry(id: 'a', amount: 1200, date: DateTime(2026, 9, 5)),
        _entry(id: 'b', amount: 3400, date: DateTime(2026, 9, 20)),
        _entry(id: 'c', amount: 500, date: DateTime(2026, 8, 1)), // 月外
      ],
      year: 2026,
      month: 9,
    );

    expect(find.byKey(CalendarAppKeys.totalAmount), findsOneWidget);
    expect(find.text('¥4,600'), findsOneWidget);
  });

  testWidgets('支出日数が表示される', (tester) async {
    await pumpScreen(
      tester,
      entries: [
        _entry(id: 'a', amount: 100, date: DateTime(2026, 9, 5)),
        _entry(id: 'b', amount: 200, date: DateTime(2026, 9, 5)),
        _entry(id: 'c', amount: 300, date: DateTime(2026, 9, 20)),
      ],
      year: 2026,
      month: 9,
    );

    expect(find.byKey(CalendarAppKeys.spendingDays), findsOneWidget);
    expect(find.textContaining('2'), findsWidgets);
  });

  testWidgets('支出0件月は空文言を表示する', (tester) async {
    await pumpScreen(tester, entries: const [], year: 2026, month: 9);

    expect(find.byKey(CalendarAppKeys.emptyMessage), findsOneWidget);
    expect(find.text('この月の支出はありません'), findsOneWidget);
  });

  testWidgets('日セルタップでダイアログにその日の明細行が出る', (tester) async {
    await pumpScreen(
      tester,
      entries: [
        _entry(id: 'x1', amount: 800, category: '食費', date: DateTime(2026, 9, 10), note: '昼ごはん'),
        _entry(id: 'x2', amount: 300, category: '交通費', date: DateTime(2026, 9, 10)),
        _entry(id: 'y1', amount: 999, date: DateTime(2026, 9, 11)),
      ],
      year: 2026,
      month: 9,
    );

    await tester.tap(find.byKey(CalendarAppKeys.dayCell(DateTime(2026, 9, 10))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(CalendarAppKeys.dayDetailDialog), findsOneWidget);
    expect(find.byKey(CalendarAppKeys.dayDetailRow('x1')), findsOneWidget);
    expect(find.byKey(CalendarAppKeys.dayDetailRow('x2')), findsOneWidget);
    expect(find.byKey(CalendarAppKeys.dayDetailRow('y1')), findsNothing);
    expect(find.text('昼ごはん'), findsOneWidget);
  });

  testWidgets('翌月ボタンは当月表示時は無効（未来へ進めない）', (tester) async {
    await pumpScreen(tester, year: 2026, month: 9);

    final next = tester.widget<IconButton>(
      find.byKey(CalendarAppKeys.nextMonthButton),
    );
    expect(next.onPressed, isNull);

    final prev = tester.widget<IconButton>(
      find.byKey(CalendarAppKeys.prevMonthButton),
    );
    expect(prev.onPressed, isNotNull);
  });

  testWidgets('前月ボタンで月ラベルが前月に変わる', (tester) async {
    await pumpScreen(tester, year: 2026, month: 9);

    await tester.tap(find.byKey(CalendarAppKeys.prevMonthButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('2026年8月'), findsOneWidget);
  });

  testWidgets('ロード失敗時は例外を投げず空でフォールバックする', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TransactionCalendarScreen(
          entriesLoader: () async => throw Exception('load failed'),
          clock: fixedClock,
          initialYear: 2026,
          initialMonth: 9,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(CalendarAppKeys.screen), findsOneWidget);
    expect(find.byKey(CalendarAppKeys.emptyMessage), findsOneWidget);
  });

  testWidgets('配線: TransactionHistoryPage にカレンダー開ボタンがあり既存ボタンも健在', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        home: TransactionHistoryPage(controller: MockTransactionController()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(CalendarAppKeys.openButton), findsOneWidget);
    expect(find.byKey(TagAppKeys.historyTagManageButton), findsOneWidget);
    expect(find.byKey(TagAppKeys.historyTagSummaryButton), findsOneWidget);
  });
}