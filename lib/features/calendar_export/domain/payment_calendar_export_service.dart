import 'package:kozuchi/features/calendar_export/domain/calendar_event.dart';
import 'package:kozuchi/features/calendar_export/domain/ics_writer.dart';
import 'package:kozuchi/features/installment/domain/installment_service.dart';
import 'package:kozuchi/features/installment/domain/models/installment_plan.dart';
import 'package:kozuchi/features/installment/domain/models/subscription.dart';
import 'package:kozuchi/features/recurring_transaction/domain/recurring_transaction.dart';

/// 書き出し対象の種別。
enum PaymentEntryKind {
  recurring('定期取引'),
  subscription('サブスク'),
  installment('分割払い');

  final String label;
  const PaymentEntryKind(this.label);
}

/// 支払い予定を iCalendar の予定へ展開する純粋ロジック。
///
/// 実時計は使わず、基準日 [now] は必ず呼び出し側から渡す。
class PaymentCalendarExportService {
  const PaymentCalendarExportService._();

  static const Set<PaymentEntryKind> allKinds = {
    PaymentEntryKind.recurring,
    PaymentEntryKind.subscription,
    PaymentEntryKind.installment,
  };

  /// [now] 当日から [months] ヶ月後までに発生する支払い予定を返す。
  ///
  /// 返り値は日付昇順→UID 昇順。無効なもの・完済済みは含めない。
  static List<CalendarEvent> buildEvents({
    required List<RecurringTransaction> recurring,
    required List<Subscription> subscriptions,
    required List<InstallmentPlan> installments,
    required DateTime now,
    int months = 3,
    Set<PaymentEntryKind> kinds = allKinds,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final until = InstallmentService.dateInMonth(
      today.year,
      today.month + (months < 0 ? 0 : months),
      today.day,
    );
    final events = <CalendarEvent>[];

    if (kinds.contains(PaymentEntryKind.recurring)) {
      for (final item in recurring) {
        if (!item.isActive) continue;
        _addRecurring(events, item, today, until);
      }
    }
    if (kinds.contains(PaymentEntryKind.subscription)) {
      for (final sub in subscriptions) {
        if (!sub.isActive) continue;
        _addSubscription(events, sub, today, until);
      }
    }
    if (kinds.contains(PaymentEntryKind.installment)) {
      for (final plan in installments) {
        if (!plan.isActive) continue;
        _addInstallment(events, plan, today, until);
      }
    }

    events.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      if (byDate != 0) return byDate;
      return a.uid.compareTo(b.uid);
    });
    return events;
  }

  /// 支払い予定を ICS 文字列へ変換する。
  static String exportIcs({
    required List<RecurringTransaction> recurring,
    required List<Subscription> subscriptions,
    required List<InstallmentPlan> installments,
    required DateTime now,
    int months = 3,
    Set<PaymentEntryKind> kinds = allKinds,
  }) {
    final events = buildEvents(
      recurring: recurring,
      subscriptions: subscriptions,
      installments: installments,
      now: now,
      months: months,
      kinds: kinds,
    );
    return IcsWriter.write(
      events,
      calendarName: '高天原の支払い',
      generatedAt: now,
    );
  }

  static void _addRecurring(
    List<CalendarEvent> out,
    RecurringTransaction item,
    DateTime from,
    DateTime until,
  ) {
    final start = DateTime(
      item.startDate.year,
      item.startDate.month,
      item.startDate.day,
    );

    void add(DateTime date) {
      if (date.isBefore(start) || date.isBefore(from) || date.isAfter(until)) {
        return;
      }
      out.add(
        _event(
          kind: PaymentEntryKind.recurring,
          id: item.id,
          date: date,
          purpose: item.purpose,
          amount: item.amount,
          category: item.category,
        ),
      );
    }

    switch (item.frequency) {
      case RecurringFrequency.daily:
        var date = start.isBefore(from) ? from : start;
        while (!date.isAfter(until)) {
          add(date);
          date = DateTime(date.year, date.month, date.day + 1);
        }
      case RecurringFrequency.weekly:
        var date = start.isBefore(from) ? from : start;
        while (!date.isAfter(until)) {
          if (date.weekday == item.dayOfWeek) add(date);
          date = DateTime(date.year, date.month, date.day + 1);
        }
      case RecurringFrequency.monthly:
        var year = from.year;
        var month = from.month;
        while (true) {
          final date = InstallmentService.dateInMonth(
            year,
            month,
            item.dayOfMonth,
          );
          if (date.isAfter(until)) break;
          add(date);
          month++;
          if (month > 12) {
            month = 1;
            year++;
          }
        }
    }
  }

  static void _addSubscription(
    List<CalendarEvent> out,
    Subscription sub,
    DateTime from,
    DateTime until,
  ) {
    final start = DateTime(
      sub.startDate.year,
      sub.startDate.month,
      sub.startDate.day,
    );
    var year = from.year;
    var month = from.month;
    while (true) {
      final date = InstallmentService.dateInMonth(year, month, sub.billingDay);
      if (date.isAfter(until)) break;
      if (!date.isBefore(start) && !date.isBefore(from)) {
        out.add(
          _event(
            kind: PaymentEntryKind.subscription,
            id: sub.id,
            date: date,
            purpose: sub.purpose,
            amount: sub.amount,
            category: sub.category,
          ),
        );
      }
      month++;
      if (month > 12) {
        month = 1;
        year++;
      }
    }
  }

  static void _addInstallment(
    List<CalendarEvent> out,
    InstallmentPlan plan,
    DateTime from,
    DateTime until,
  ) {
    if (plan.isCompleted || plan.installmentCount <= 0) return;
    final first = InstallmentService.nextPaymentDate(plan);
    if (first == null) return;

    final perPayment = plan.totalAmount ~/ plan.installmentCount;
    for (var i = 0; i < plan.remainingCount; i++) {
      final date = InstallmentService.dateInMonth(
        first.year,
        first.month + i,
        first.day,
      );
      if (date.isAfter(until)) break;
      if (date.isBefore(from)) continue;
      out.add(
        _event(
          kind: PaymentEntryKind.installment,
          id: plan.id,
          date: date,
          purpose: plan.purpose,
          amount: perPayment,
          category: plan.category,
        ),
      );
    }
  }

  static CalendarEvent _event({
    required PaymentEntryKind kind,
    required String id,
    required DateTime date,
    required String purpose,
    required int amount,
    required String category,
  }) {
    final event = CalendarEvent(
      uid: '',
      date: DateTime(date.year, date.month, date.day),
      summary: '『$purpose ¥${amount.abs()}』',
      description: '種別: ${kind.label} / カテゴリ: $category',
    );
    return CalendarEvent(
      uid: 'koz-${kind.name}-$id-${event.dateStamp}@takamagahara',
      date: event.date,
      summary: event.summary,
      description: event.description,
    );
  }
}
