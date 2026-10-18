// 親探針: 画面→サービス→ICS の合成不変条件と月末クランプ。
//
// 眷属の試練は種別ごとの展開を個別検証しがちなので、
// 「画面の件数＝実際の VEVENT 数」「月末調整が ICS の DTSTART に現れる」を親が撃つ。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/calendar_export/data/ics_share_exporter.dart';
import 'package:kozuchi/features/calendar_export/domain/payment_calendar_export_service.dart';
import 'package:kozuchi/features/calendar_export/presentation/calendar_export_keys.dart';
import 'package:kozuchi/features/calendar_export/presentation/calendar_export_screen.dart';
import 'package:kozuchi/features/installment/domain/models/subscription.dart';
import 'package:kozuchi/features/recurring_transaction/domain/recurring_transaction.dart';

class _RecordingExporter implements IcsShareExporter {
  String? ics;

  @override
  Future<void> export({required String ics, required String fileName}) async {
    this.ics = ics;
  }
}

final _now = DateTime(2026, 1, 15);

RecurringTransaction _monthly(String id, String purpose, int day) =>
    RecurringTransaction(
      id: id,
      purpose: purpose,
      category: '住居',
      amount: -1000,
      frequency: RecurringFrequency.monthly,
      dayOfMonth: day,
      startDate: DateTime(2026, 1, 1),
    );

Subscription _sub(String id, String purpose, int billingDay) => Subscription(
      id: id,
      purpose: purpose,
      category: '趣味',
      amount: 1200,
      billingDay: billingDay,
      startDate: DateTime(2026, 1, 1),
    );

int _veventCount(String ics) =>
    RegExp(r'BEGIN:VEVENT\r\n').allMatches(ics).length;

void main() {
  testWidgets('画面の件数ラベルと書き出した VEVENT 数が一致する', (tester) async {
    final fake = _RecordingExporter();
    await tester.pumpWidget(
      MaterialApp(
        home: CalendarExportScreen(
          recurringOverride: [_monthly('r1', '家賃', 25)],
          subscriptionsOverride: [_sub('s1', '動画', 25)],
          installmentsOverride: const [],
          exporter: fake,
          now: _now,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1/25, 2/25, 3/25 の2種 = 6件（今日〜3ヶ月後）
    expect(find.text('6件'), findsOneWidget);

    await tester.tap(find.byKey(CalendarExportAppKeys.exportButton));
    await tester.pumpAndSettle();

    expect(fake.ics, isNotNull);
    expect(_veventCount(fake.ics!), 6);
  });

  testWidgets('月末クランプ（31日→2月28日）が DTSTART に反映される', (tester) async {
    final fake = _RecordingExporter();
    await tester.pumpWidget(
      MaterialApp(
        home: CalendarExportScreen(
          recurringOverride: [_monthly('r31', '末日払い', 31)],
          subscriptionsOverride: const [],
          installmentsOverride: const [],
          exporter: fake,
          now: _now,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(CalendarExportAppKeys.exportButton));
    await tester.pumpAndSettle();

    final ics = fake.ics!;
    expect(ics, contains('DTSTART;VALUE=DATE:20260131'));
    expect(ics, contains('DTSTART;VALUE=DATE:20260228'));
    expect(ics, isNot(contains('DTSTART;VALUE=DATE:20260231')));
  });

  test('種別フィルタで対象が絞られ、入力リストは破壊されない', () {
    final recurring = [_monthly('r1', '家賃', 25)];
    final subs = [_sub('s1', '動画', 25)];

    final onlySubs = PaymentCalendarExportService.buildEvents(
      recurring: recurring,
      subscriptions: subs,
      installments: const [],
      now: _now,
      kinds: const {PaymentEntryKind.subscription},
    );
    expect(onlySubs.length, 3);
    expect(onlySubs.every((e) => e.uid.startsWith('koz-subscription-')), isTrue);

    // 入力は非破壊（呼び出しで件数が変わらない）
    expect(recurring.length, 1);
    expect(subs.length, 1);
  });
}
