// 親探針（イシコリドメ）: 眷属Aが個別にしか撃たなかった「合成の不変条件」を撃つ。
// weeks × weeklyTotals × days × totalAmount × maxDay の相互整合を独立に再計算して照合する。
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/features/calendar/domain/calendar_service.dart';

ExpenseEntry _e(String id, int amount, DateTime date) =>
    ExpenseEntry(id: id, amount: amount, category: '食費', date: date);

void main() {
  const service = CalendarService();

  /// 検証対象の年月（月初が日曜/土曜/月曜/火曜、うるう年2月を含む）
  const cases = <(int, int)>[
    (2026, 2),
    (2026, 5),
    (2026, 8),
    (2026, 9),
    (2024, 2),
    (2025, 12),
  ];

  test('probe: weeks を平坦化した非null列 == days（順序込み）', () {
    for (final (y, m) in cases) {
      final cal = service.build(entries: const [], year: y, month: m);
      final flat = <dynamic>[];
      for (final row in cal.weeks) {
        for (final cell in row) {
          if (cell != null) flat.add(cell);
        }
      }
      expect(flat.length, cal.days.length, reason: '$y-$m');
      for (var i = 0; i < flat.length; i++) {
        expect((flat[i] as dynamic).date, cal.days[i].date, reason: '$y-$m[$i]');
      }
    }
  });

  test('probe: 各行は必ず7要素・行数は ceil((leadingBlanks+daysInMonth)/7)', () {
    for (final (y, m) in cases) {
      final cal = service.build(entries: const [], year: y, month: m);
      final expectedRows =
          ((cal.leadingBlanks + cal.daysInMonth) / 7).ceil();
      expect(cal.weeks.length, expectedRows, reason: '$y-$m');
      for (final row in cal.weeks) {
        expect(row.length, 7, reason: '$y-$m');
      }
      // 先頭行の leadingBlanks 個は null
      for (var i = 0; i < cal.leadingBlanks; i++) {
        expect(cal.weeks.first[i], isNull, reason: '$y-$m[$i]');
      }
    }
  });

  test('probe: weeklyTotals[i] == weeks[i] の非nullセル合計 / 総和==totalAmount', () {
    final entries = <ExpenseEntry>[
      _e('a', 1000, DateTime(2026, 9, 1)),
      _e('b', 2500, DateTime(2026, 9, 1)),
      _e('c', 300, DateTime(2026, 9, 6)),
      _e('d', 9999, DateTime(2026, 9, 15)),
      _e('e', 1, DateTime(2026, 9, 30)),
    ];
    final cal = service.build(entries: entries, year: 2026, month: 9);
    expect(cal.weeklyTotals.length, cal.weeks.length);
    for (var i = 0; i < cal.weeks.length; i++) {
      var sum = 0;
      for (final c in cal.weeks[i]) {
        sum += c?.totalAmount ?? 0;
      }
      expect(cal.weeklyTotals[i], sum, reason: '週$i');
    }
    expect(cal.weeklyTotals.fold<int>(0, (a, b) => a + b), cal.totalAmount);
    expect(cal.totalAmount, 13800);
    // days の合計とも一致
    expect(cal.days.fold<int>(0, (a, d) => a + d.totalAmount), cal.totalAmount);
  });

  test('probe: maxDay は entry から独立再計算した最大日と一致（同額は早い日）', () {
    final entries = <ExpenseEntry>[
      _e('x1', 700, DateTime(2026, 9, 20)),
      _e('x2', 700, DateTime(2026, 9, 3)),
      _e('x3', 100, DateTime(2026, 9, 3)),
    ];
    final cal = service.build(entries: entries, year: 2026, month: 9);
    expect(cal.maxDay!.date.day, 3);
    expect(cal.maxDay!.date.month, 9);
    expect(cal.maxDay!.totalAmount, 800);
    expect(cal.spendingDayCount, 2);
    // 支出なし月は maxDay null / isEmpty true
    final empty = service.build(entries: const [], year: 2026, month: 9);
    expect(empty.maxDay, isNull);
    expect(empty.isEmpty, isTrue);
    expect(empty.days.length, 30);
  });

  test('probe: 月外 entry は days/maxDay に一切影響しない', () {
    // NOTE: amount <= 0 は ExpenseEntry の assert で構築不能ゆえ service 側フィルタは
    // 眷属Aの試練（getter差し替えサブクラス）が担保する。
    final entries = <ExpenseEntry>[
      _e('in', 500, DateTime(2026, 9, 10)),
      _e('outPrev', 99999, DateTime(2026, 8, 31)),
      _e('outNext', 99999, DateTime(2026, 10, 1)),
    ];
    final cal = service.build(entries: entries, year: 2026, month: 9);
    expect(cal.totalAmount, 500);
    expect(cal.spendingDayCount, 1);
    expect(cal.maxDay!.totalAmount, 500);
    expect(cal.summaryFor(10).entryCount, 1);
  });

  test('probe: shiftMonth の往復一貫性（+n して -n で戻る）', () {
    for (final (y, m) in cases) {
      for (final n in [1, 3, 12, 25]) {
        final f = service.shiftMonth(year: y, month: m, deltaMonths: n);
        final b = service.shiftMonth(
            year: f.year, month: f.month, deltaMonths: -n);
        expect((b.year, b.month), (y, m), reason: '$y-$m +$n');
      }
    }
  });
}
