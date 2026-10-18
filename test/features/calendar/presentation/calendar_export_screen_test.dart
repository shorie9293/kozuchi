import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/calendar_export/data/ics_share_exporter.dart';
import 'package:kozuchi/features/calendar_export/presentation/calendar_export_keys.dart';
import 'package:kozuchi/features/calendar_export/presentation/calendar_export_screen.dart';
import 'package:kozuchi/features/calendar_export/domain/payment_calendar_export_service.dart';
import 'package:kozuchi/features/recurring_transaction/domain/recurring_transaction.dart';

/// 書き出し内容を捕捉する偽エクスポーター。
class _RecordingExporter implements IcsShareExporter {
  final List<String> received = [];

  @override
  Future<void> export({required String ics, required String fileName}) async {
    received.add(ics);
  }
}

/// 実時計を使わない固定基準日。
final _now = DateTime(2026, 1, 15);

ReccurringFixture get _fixture => ReccurringFixture();

/// テスト用の定期取引（毎月20日・家賃）。
class ReccurringFixture {
  List<RecurringTransaction> get items => [
        RecurringTransaction(
          id: 'r1',
          purpose: '家賃',
          category: '住居',
          amount: -80000,
          frequency: RecurringFrequency.monthly,
          dayOfMonth: 20,
          startDate: DateTime(2026, 1, 1),
        ),
      ];
}

Future<void> _pump(
  WidgetTester tester, {
  required IcsShareExporter exporter,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: CalendarExportScreen(
        recurringOverride: _fixture.items,
        subscriptionsOverride: const [],
        installmentsOverride: const [],
        exporter: exporter,
        now: _now,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('期間内の発生件数を表示する', (tester) async {
    await _pump(tester, exporter: _RecordingExporter());

    expect(find.byKey(CalendarExportAppKeys.screen), findsOneWidget);
    expect(find.text('支払い予定の書き出し'), findsOneWidget);
    // 1/20, 2/20, 3/20（4/20 は範囲外）
    expect(find.byKey(CalendarExportAppKeys.countLabel), findsOneWidget);
    expect(find.text('3件'), findsOneWidget);
    expect(find.textContaining('01/20'), findsOneWidget);
  });

  testWidgets('種別チップで件数が変わる', (tester) async {
    await _pump(tester, exporter: _RecordingExporter());

    expect(find.text('3件'), findsOneWidget);

    await tester.tap(
      find.byKey(CalendarExportAppKeys.kindChip(PaymentEntryKind.recurring)),
    );
    await tester.pumpAndSettle();

    expect(find.text('0件'), findsOneWidget);
    expect(find.byKey(CalendarExportAppKeys.emptyLabel), findsOneWidget);
  });

  testWidgets('書き出しタップで VEVENT と purpose を含む ICS を渡す', (tester) async {
    final exporter = _RecordingExporter();
    await _pump(tester, exporter: exporter);

    await tester.tap(find.byKey(CalendarExportAppKeys.exportButton));
    await tester.pumpAndSettle();

    expect(exporter.received, hasLength(1));
    expect(exporter.received.single, contains('BEGIN:VEVENT'));
    expect(exporter.received.single, contains('家賃'));
    expect(find.text('支払い予定を書き出しました'), findsOneWidget);
  });

  testWidgets('0件なら書き出しボタンは無効', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CalendarExportScreen(
          recurringOverride: const [],
          subscriptionsOverride: const [],
          installmentsOverride: const [],
          exporter: _RecordingExporter(),
          now: _now,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.byKey(CalendarExportAppKeys.exportButton),
    );
    expect(button.onPressed, isNull);
    expect(find.byKey(CalendarExportAppKeys.emptyLabel), findsOneWidget);
  });
}
