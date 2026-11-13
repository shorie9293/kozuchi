import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/features/budget/domain/category_budget_suggestion_service.dart';
import 'package:kozuchi/features/calendar/domain/calendar_service.dart';
import 'package:kozuchi/features/calendar/domain/day_expense_summary.dart';
import 'package:kozuchi/features/income/domain/models/income_entry.dart';
import 'package:kozuchi/features/income/domain/services/income_analysis_service.dart';

/// 親探針: クラウド復元後のローカル日付と、読取側のタイムゾーン防御。
///
/// 「保存形式」と「日付の切り出し」は別契約である。
/// クラウドは Z 付き（UTC）で送るため、復元した瞬間を `.year/.month/.day` で
/// 直読みすると JST 00:00〜08:59 は前日、月初は前月に落ちる。
void main() {
  ExpenseEntry entryAt(DateTime local, {String id = 'e1', int amount = 500}) =>
      ExpenseEntry(id: id, amount: amount, category: '食費', date: local);

  String cloudIsoOf(DateTime local) => local.toUtc().toIso8601String();

  group('親探針1: クラウド往復でローカル暦が動かない', () {
    test('月初 00:05 の取引が前月へ落ちない（カレンダー集計）', () {
      final local = DateTime(2026, 11, 1, 0, 5);
      final restored = ExpenseEntry.fromJson({
        'id': 'e1',
        'amount': 500,
        'category': '食費',
        'date': cloudIsoOf(local),
      });

      final november = const CalendarService().build(
        entries: [restored],
        year: 2026,
        month: 11,
      );
      final october = const CalendarService().build(
        entries: [restored],
        year: 2026,
        month: 10,
      );

      expect(november.days[0].totalAmount, 500, reason: '11/1 に載る');
      expect(november.days[0].entryCount, 1);
      expect(
        october.days.fold<int>(0, (sum, d) => sum + d.totalAmount),
        0,
        reason: '前月へ二重計上しない',
      );
    });

    test('早朝 08:59 の取引が前日へ落ちない（日別サマリ）', () {
      final local = DateTime(2026, 11, 13, 8, 59);
      final restored = ExpenseEntry.fromJson({
        'id': 'e2',
        'amount': 800,
        'category': '交通費',
        'date': cloudIsoOf(local),
      });
      final calendar = const CalendarService().build(
        entries: [restored],
        year: 2026,
        month: 11,
      );
      expect(calendar.days[12].totalAmount, 800, reason: '11/13 に載る');
      expect(calendar.days[11].totalAmount, 0, reason: '11/12 に落ちない');
    });

    test('既存のローカル保存（Z 無し）は不変', () {
      final original = entryAt(DateTime(2026, 6, 22, 14, 30));
      final json = original.toJson();
      expect(json['date'], isNot(contains('Z')));
      final restored = ExpenseEntry.fromJson(json);
      expect(restored.date, original.date);
      expect(restored.toJson()['date'], json['date']);
    });

    test('TZ に依らず往復は同値（期待値は toLocal から算出）', () {
      final instants = [
        DateTime.parse('2026-11-12T23:30:00.000Z'),
        DateTime.parse('2026-10-31T15:05:00.000Z'),
        DateTime.parse('2026-12-31T14:59:00.000Z'),
      ];
      for (final instant in instants) {
        final restored = ExpenseEntry.fromJson({
          'id': 'e3',
          'amount': 100,
          'category': 'その他',
          'date': instant.toIso8601String(),
        });
        final local = instant.toLocal();
        expect(restored.date.year, local.year);
        expect(restored.date.month, local.month);
        expect(restored.date.day, local.day);
        expect(restored.date.isUtc, isFalse);
      }
    });

    test('壊れた日付文字列は throw せず読み飛ばせる', () {
      expect(
        ExpenseEntry.tryFromJson({
          'id': 'e4',
          'amount': 100,
          'category': 'その他',
          'date': 'totally-broken-date',
        }),
        isNull,
      );
    });
  });

  group('親探針2: 読取側は UTC 種別の瞬間が直接渡っても正しい日付を出す', () {
    test('DayExpenseSummary は UTC 種別の entry を同日として受理する', () {
      final utc = DateTime.parse('2026-11-12T23:30:00.000Z'); // JST 11/13 08:30
      final local = utc.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      final entry = ExpenseEntry(
        id: 'e5',
        amount: 300,
        category: '食費',
        date: utc,
      );
      expect(
        () => DayExpenseSummary(date: day, totalAmount: 300, entries: [entry]),
        returnsNormally,
      );
    });

    test('カテゴリ別予算の月キーはローカル暦で作られる', () {
      final utc = DateTime.parse('2026-10-31T15:05:00.000Z'); // JST 11/01 00:05
      final local = utc.toLocal();
      final now = DateTime(local.year, local.month, 15);
      final suggestions = const CategoryBudgetSuggestionService().suggest(
        entries: [
          ExpenseEntry(id: 'e6', amount: 5000, category: '食費', date: utc),
        ],
        now: now,
        monthsToConsider: 2,
      );
      expect(suggestions, isNotEmpty);
      final food = suggestions.firstWhere((s) => s.category == '食費');
      expect(food.recommendedBudget, greaterThan(0),
          reason: '当月の窓に入らないと提案が0件になる');
      expect(food.monthsWithSpend, 1,
          reason: '月初 00:05 の取引が当月として数えられる');
    });

    test('収入の期間絞込は UTC 種別でもローカル日で判定する', () {
      final utc = DateTime.parse('2026-11-12T23:30:00.000Z'); // JST 11/13
      final local = utc.toLocal();
      final entry = IncomeEntry(
        id: 'i1',
        amount: 1000,
        source: '給与',
        date: utc,
      );
      final filtered = IncomeAnalysisService.filterByPeriod(
        [entry],
        start: DateTime(local.year, local.month, local.day),
        end: DateTime(local.year, local.month, local.day),
      );
      expect(filtered, hasLength(1));
    });
  });
}
