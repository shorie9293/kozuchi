import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/domain/services/expense_repository.dart';
import 'package:kozuchi/features/income/domain/models/income_entry.dart';
import 'package:kozuchi/features/income/domain/services/income_repository.dart';
import 'package:kozuchi/features/monthly_report/presentation/screens/monthly_report_screen.dart';
import 'package:kozuchi/features/shared/presentation/kozuchi_app_keys.dart';
import 'package:kozuchi/features/summary_chart/presentation/screens/summary_screen.dart';

/// 親探針用: 期間で絞り込んで返すフェイクリポジトリ
class _RangeExpenseRepository implements ExpenseRepository {
  _RangeExpenseRepository(this.entries);

  final List<ExpenseEntry> entries;

  @override
  Future<List<ExpenseEntry>> getEntries({
    required DateTime start,
    required DateTime end,
  }) async {
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    return entries.where((entry) {
      final day = DateTime(entry.date.year, entry.date.month, entry.date.day);
      return !day.isBefore(s) && !day.isAfter(e);
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
  Future<void> deleteEntry(String id) async {}

  @override
  Future<ExpenseEntry?> getEntryById(String id) async => null;
}

ExpenseEntry _expense({
  required String id,
  required int amount,
  required DateTime date,
  String category = '食費',
}) =>
    ExpenseEntry(id: id, amount: amount, category: category, date: date);

IncomeEntry _income({
  required String id,
  required int amount,
  required DateTime date,
  String source = '給与',
}) =>
    IncomeEntry(id: id, amount: amount, source: source, date: date);

/// WashiBackground が無限アニメーション（repeat）のため pumpAndSettle は使えない。
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _pumpSummary(
  WidgetTester tester, {
  required ExpenseRepository repository,
  IncomeRepository? incomeRepository,
}) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: SummaryScreen(
        repository: repository,
        incomeRepository: incomeRepository,
      ),
    ),
  );
  await _settle(tester);
}

Future<void> _pumpMonthlyReport(
  WidgetTester tester, {
  required ExpenseRepository repository,
  IncomeRepository? incomeRepository,
  required DateTime initialMonth,
}) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: MonthlyReportScreen(
        repository: repository,
        incomeRepository: incomeRepository,
        initialMonth: initialMonth,
        now: initialMonth,
      ),
    ),
  );
  await _settle(tester);
}

void main() {
  group('親探針: 収入合流の合成不変条件', () {
    testWidgets('支出サマリー画面から渡した収入リポジトリが月次レポートまで貫通する',
        (tester) async {
      // 支出サマリー → 月次レポートの導線で incomeRepository が
      // 落ちていないこと（SummaryScreen が中継していること）を撃つ。
      // SummaryScreen 経由の月次レポートは実時計の当月を表示するため、
      // 素材も実時計の当月に作る（暦が進んでも壊れない）。
      final now = DateTime.now();
      final day = DateTime(now.year, now.month, 5);
      final incomes = InMemoryIncomeRepository();
      await incomes.saveEntry(_income(id: 'i1', amount: 300000, date: day));
      final reports = _RangeExpenseRepository([
        _expense(id: '1', amount: 200000, date: day),
      ]);

      await _pumpSummary(tester, repository: reports, incomeRepository: incomes);
      await tester.tap(find.byKey(KozuchiAppKeys.monthlyReportEntry));
      await _settle(tester);

      // 導線が渡したリポジトリがそのまま画面へ届いている（中継の証拠）
      final screen = tester.widget<MonthlyReportScreen>(
        find.byType(MonthlyReportScreen),
      );
      expect(identical(screen.incomeRepository, incomes), isTrue);

      expect(find.text('300000円'), findsOneWidget);
      expect(find.text('+100000円'), findsOneWidget);
      expect(find.text('貯蓄率 33.3%'), findsOneWidget);
    });

    testWidgets('前月の収入が当月の前月比（支出のみ比較）を汚染しない', (tester) async {
      // 前月比は「支出のみ」の比較という既存意味論の固定。
      // 前月に多額の収入があっても前月比は 0%（支出同額）でなければならない。
      final incomes = InMemoryIncomeRepository();
      await incomes.saveEntry(
        _income(id: 'i_prev', amount: 500000, date: DateTime(2026, 8, 20)),
      );
      final reports = _RangeExpenseRepository([
        _expense(id: 'cur', amount: 100000, date: DateTime(2026, 9, 5)),
        _expense(id: 'prev', amount: 100000, date: DateTime(2026, 8, 5)),
      ]);

      await _pumpMonthlyReport(
        tester,
        repository: reports,
        incomeRepository: incomes,
        initialMonth: DateTime(2026, 9, 1),
      );

      // 当月は収入0件
      expect(find.text('0円'), findsOneWidget); // 収入行
      expect(find.text('貯蓄率 0.0%'), findsOneWidget);
      // 前月比は支出のみ比較ゆえ「先月とほぼ同じ」
      expect(find.text('前月比 先月とほぼ同じ'), findsOneWidget);
    });

    testWidgets('収入リポジトリ未注入の既定は Noop（収入0件・従来挙動）', (tester) async {
      // 既存の呼出（incomeRepository を渡さない）が従来どおりであることの回帰。
      final reports = _RangeExpenseRepository([
        _expense(id: '1', amount: 60000, date: DateTime(2026, 9, 3)),
      ]);

      await _pumpMonthlyReport(
        tester,
        repository: reports,
        initialMonth: DateTime(2026, 9, 1),
      );

      expect(find.text('0円'), findsOneWidget);
      expect(find.text('貯蓄率 0.0%'), findsOneWidget);
      expect(find.text('-60000円'), findsOneWidget);
    });

    testWidgets('収入のみの月でもレポートが空にならず貯蓄率100%を表示する', (tester) async {
      final incomes = InMemoryIncomeRepository();
      await incomes.saveEntry(
        _income(id: 'i1', amount: 50000, date: DateTime(2026, 9, 30)),
      );

      await _pumpMonthlyReport(
        tester,
        repository: _RangeExpenseRepository(const []),
        incomeRepository: incomes,
        initialMonth: DateTime(2026, 9, 1),
      );

      expect(find.text('50000円'), findsOneWidget);
      expect(find.text('+50000円'), findsOneWidget);
      expect(find.text('貯蓄率 100.0%'), findsOneWidget);
      expect(find.text('この月の記録はありません'), findsNothing);
    });
  });
}
