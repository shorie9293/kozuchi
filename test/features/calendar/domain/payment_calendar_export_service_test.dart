import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/calendar_export/domain/calendar_event.dart';
import 'package:kozuchi/features/calendar_export/domain/payment_calendar_export_service.dart';
import 'package:kozuchi/features/installment/domain/models/installment_plan.dart';
import 'package:kozuchi/features/installment/domain/models/subscription.dart';
import 'package:kozuchi/features/recurring_transaction/domain/recurring_transaction.dart';

/// 実時計を使わない固定基準日（時限爆弾回避）。
final _now = DateTime(2026, 1, 15);

List<String> _stamps(List<CalendarEvent> events) =>
    events.map((e) => e.dateStamp).toList();

void main() {
  group('定期取引の展開', () {
    test('daily は基準日以降の各日を範囲内で展開する', () {
      final events = PaymentCalendarExportService.buildEvents(
        recurring: [
          RecurringTransaction(
            id: 'r1',
            purpose: 'お小遣い',
            category: '娯楽',
            amount: -500,
            frequency: RecurringFrequency.daily,
            startDate: DateTime(2026, 1, 10),
          ),
        ],
        subscriptions: const [],
        installments: const [],
        now: _now,
        months: 1,
      );

      // 1/15 〜 2/15 の 32 日
      expect(events.length, 32);
      expect(events.first.dateStamp, '20260115');
      expect(events.last.dateStamp, '20260215');
    });

    test('weekly は dayOfWeek に一致する日のみ、startDate より前は出さない', () {
      final events = PaymentCalendarExportService.buildEvents(
        recurring: [
          RecurringTransaction(
            id: 'r2',
            purpose: 'ジム',
            category: '健康',
            amount: -3000,
            frequency: RecurringFrequency.weekly,
            dayOfWeek: DateTime.monday,
            startDate: DateTime(2026, 1, 1),
          ),
        ],
        subscriptions: const [],
        installments: const [],
        now: _now,
        months: 1,
      );

      expect(_stamps(events), ['20260119', '20260126', '20260202', '20260209']);
      for (final e in events) {
        expect(e.date.weekday, DateTime.monday);
      }
    });

    test('monthly は月末クランプし、startDate より前を出さない', () {
      final events = PaymentCalendarExportService.buildEvents(
        recurring: [
          RecurringTransaction(
            id: 'r3',
            purpose: '家賃',
            category: '住居',
            amount: -80000,
            frequency: RecurringFrequency.monthly,
            dayOfMonth: 31,
            startDate: DateTime(2026, 1, 20),
          ),
        ],
        subscriptions: const [],
        installments: const [],
        now: _now,
        months: 2,
      );

      // 1/31（startDate 1/20 以降）、2/28（月末クランプ）、3/31 は範囲外
      expect(_stamps(events), ['20260131', '20260228']);
    });

    test('isActive=false は除外する', () {
      final events = PaymentCalendarExportService.buildEvents(
        recurring: [
          RecurringTransaction(
            id: 'r4',
            purpose: '停止中',
            category: 'その他',
            amount: -1000,
            frequency: RecurringFrequency.monthly,
            dayOfMonth: 20,
            startDate: DateTime(2026, 1, 1),
            isActive: false,
          ),
        ],
        subscriptions: const [],
        installments: const [],
        now: _now,
        months: 1,
      );

      expect(events, isEmpty);
    });
  });

  group('サブスクの展開', () {
    test('billingDay を各月で月末クランプして展開する', () {
      final events = PaymentCalendarExportService.buildEvents(
        recurring: const [],
        subscriptions: [
          Subscription(
            id: 's1',
            purpose: '動画サブスク',
            category: '趣味',
            amount: 1200,
            billingDay: 31,
            startDate: DateTime(2025, 12, 1),
          ),
        ],
        installments: const [],
        now: _now,
        months: 2,
      );

      expect(_stamps(events), ['20260131', '20260228']);
    });
  });

  group('分割払いの展開', () {
    test('次回支払日を起点に残回数ぶん展開する', () {
      final events = PaymentCalendarExportService.buildEvents(
        recurring: const [],
        subscriptions: const [],
        installments: [
          InstallmentPlan(
            id: 'i1',
            purpose: '冷蔵庫',
            category: '家電',
            totalAmount: 90000,
            installmentCount: 3,
            startDate: DateTime(2025, 12, 15),
          ),
        ],
        now: _now,
        months: 1,
      );

      // 12/15 は過去、1/15 と 2/15 が範囲内
      expect(_stamps(events), ['20260115', '20260215']);
    });

    test('完済済みは 0 件', () {
      final events = PaymentCalendarExportService.buildEvents(
        recurring: const [],
        subscriptions: const [],
        installments: [
          InstallmentPlan(
            id: 'i2',
            purpose: '完済済み',
            category: '家電',
            totalAmount: 30000,
            installmentCount: 3,
            startDate: DateTime(2025, 10, 15),
            paidCount: 3,
          ),
        ],
        now: _now,
      );

      expect(events, isEmpty);
    });
  });

  group('種別フィルタと出力', () {
    List<CalendarEvent> build({Set<PaymentEntryKind>? kinds}) =>
        PaymentCalendarExportService.buildEvents(
          recurring: [
            RecurringTransaction(
              id: 'r1',
              purpose: '家賃',
              category: '住居',
              amount: -80000,
              frequency: RecurringFrequency.monthly,
              dayOfMonth: 20,
              startDate: DateTime(2026, 1, 1),
            ),
          ],
          subscriptions: [
            Subscription(
              id: 's1',
              purpose: '動画サブスク',
              category: '趣味',
              amount: 1200,
              billingDay: 20,
              startDate: DateTime(2025, 12, 1),
            ),
          ],
          installments: [
            InstallmentPlan(
              id: 'i1',
              purpose: '冷蔵庫',
              category: '家電',
              totalAmount: 90000,
              installmentCount: 3,
              startDate: DateTime(2026, 1, 1),
            ),
          ],
          now: _now,
          months: 2,
          kinds: kinds ??
              const {
                PaymentEntryKind.recurring,
                PaymentEntryKind.subscription,
                PaymentEntryKind.installment,
              },
        );

    test('kinds に含まれる種別のみ展開する', () {
      final onlySub = build(kinds: const {PaymentEntryKind.subscription});
      expect(onlySub.length, 2);
      for (final e in onlySub) {
        expect(e.uid, startsWith('koz-subscription-'));
      }
    });

    test('UID は一意で、日付→uid 昇順に並ぶ', () {
      final events = build();
      final uids = events.map((e) => e.uid).toSet();
      expect(uids.length, events.length);
      for (final e in events) {
        expect(e.uid, endsWith('@takamagahara'));
      }
      for (var i = 1; i < events.length; i++) {
        final prev = events[i - 1];
        final cur = events[i];
        final cmp = prev.date.compareTo(cur.date);
        expect(
            cmp < 0 || (cmp == 0 && prev.uid.compareTo(cur.uid) <= 0), isTrue);
      }
    });

    test('summary は『名称 ¥金額』で、description に種別とカテゴリを持つ', () {
      final events = build();
      final rent = events.firstWhere((e) => e.uid.startsWith('koz-recurring-'));
      expect(rent.summary, '『家賃 ¥80000』');
      expect(rent.description, '種別: 定期取引 / カテゴリ: 住居');

      final sub =
          events.firstWhere((e) => e.uid.startsWith('koz-subscription-'));
      expect(sub.summary, '『動画サブスク ¥1200』');
      expect(sub.description, '種別: サブスク / カテゴリ: 趣味');
    });

    test('installment の金額は総額÷回数の切り捨て概算', () {
      final events = build(kinds: const {PaymentEntryKind.installment});
      expect(events.first.summary, '『冷蔵庫 ¥30000』');
      expect(events.first.description, '種別: 分割払い / カテゴリ: 家電');
    });

    test('exportIcs は VCALENDAR に SUMMARY と VEVENT を含む', () {
      final ics = PaymentCalendarExportService.exportIcs(
        recurring: [
          RecurringTransaction(
            id: 'r1',
            purpose: '家賃',
            category: '住居',
            amount: -80000,
            frequency: RecurringFrequency.monthly,
            dayOfMonth: 20,
            startDate: DateTime(2026, 1, 1),
          ),
        ],
        subscriptions: const [],
        installments: const [],
        now: _now,
        months: 1,
      );

      expect(ics, contains('BEGIN:VCALENDAR'));
      expect(ics, contains('X-WR-CALNAME:高天原の支払い'));
      expect(ics, contains('BEGIN:VEVENT'));
      expect(ics, contains('SUMMARY:『家賃 ¥80000』'));
      expect(ics, contains('DTSTART;VALUE=DATE:20260120'));
    });
  });
}
