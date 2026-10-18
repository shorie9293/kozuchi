import 'package:flutter/material.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';

import 'package:kozuchi/features/calendar_export/data/ics_share_exporter.dart';
import 'package:kozuchi/features/calendar_export/domain/calendar_event.dart';
import 'package:kozuchi/features/calendar_export/domain/payment_calendar_export_service.dart';
import 'package:kozuchi/features/calendar_export/presentation/calendar_export_keys.dart';
import 'package:kozuchi/features/installment/domain/models/installment_plan.dart';
import 'package:kozuchi/features/installment/domain/models/subscription.dart';
import 'package:kozuchi/features/recurring_transaction/domain/recurring_transaction.dart';

/// 支払い予定を iCalendar (.ics) として書き出す画面。
///
/// データ・共有・基準日はすべて外部依存として注入可能（テスト差し替え用）。
class CalendarExportScreen extends StatefulWidget {
  final List<RecurringTransaction>? recurringOverride;
  final List<Subscription>? subscriptionsOverride;
  final List<InstallmentPlan>? installmentsOverride;
  final IcsShareExporter? exporter;
  final DateTime? now;

  const CalendarExportScreen({
    super.key,
    this.recurringOverride,
    this.subscriptionsOverride,
    this.installmentsOverride,
    this.exporter,
    this.now,
  });

  @override
  State<CalendarExportScreen> createState() => _CalendarExportScreenState();
}

class _CalendarExportScreenState extends State<CalendarExportScreen> {
  static const String _fileName = 'kozuchi_payments.ics';

  final Set<PaymentEntryKind> _kinds = {
    ...PaymentCalendarExportService.allKinds
  };

  IcsShareExporter get _exporter =>
      widget.exporter ?? const SharePlusIcsShareExporter();

  DateTime get _now => widget.now ?? DateTime.now();

  List<RecurringTransaction> get _recurring =>
      widget.recurringOverride ?? const [];

  List<Subscription> get _subscriptions =>
      widget.subscriptionsOverride ?? const [];

  List<InstallmentPlan> get _installments =>
      widget.installmentsOverride ?? const [];

  List<CalendarEvent> get _events => PaymentCalendarExportService.buildEvents(
        recurring: _recurring,
        subscriptions: _subscriptions,
        installments: _installments,
        now: _now,
        kinds: _kinds,
      );

  Future<void> _export() async {
    final ics = PaymentCalendarExportService.exportIcs(
      recurring: _recurring,
      subscriptions: _subscriptions,
      installments: _installments,
      now: _now,
      kinds: _kinds,
    );
    try {
      await _exporter.export(ics: ics, fileName: _fileName);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('支払い予定を書き出しました')),
      );
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('書き出しに失敗しました: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final events = _events;
    final preview = events.take(10).toList();

    return Scaffold(
      key: CalendarExportAppKeys.screen,
      appBar: AppBar(title: const Text('支払い予定の書き出し')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '期間内の支払い予定をカレンダーに取り込める .ics として書き出します。',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final kind in PaymentEntryKind.values)
                FilterChip(
                  key: CalendarExportAppKeys.kindChip(kind),
                  label: Text(kind.label),
                  selected: _kinds.contains(kind),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _kinds.add(kind);
                      } else {
                        _kinds.remove(kind);
                      }
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${events.length}件',
            key: CalendarExportAppKeys.countLabel,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (preview.isEmpty)
            Text(
              '該当する支払い予定はありません',
              key: CalendarExportAppKeys.emptyLabel,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            )
          else
            Column(
              key: CalendarExportAppKeys.previewList,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final event in preview)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '${_monthDay(event.date)} ${event.summary}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                if (events.length > preview.length)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'ほか ${events.length - preview.length}件',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 24),
          SemanticHelper.interactive(
            testId: 'calendar_export_btn_export',
            label: '支払い予定を書き出す',
            child: FilledButton.icon(
              key: CalendarExportAppKeys.exportButton,
              onPressed: events.isEmpty ? null : _export,
              icon: const Icon(Icons.ios_share),
              label: const Text('書き出す'),
            ),
          ),
        ],
      ),
    );
  }

  String _monthDay(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$m/$d';
  }
}
