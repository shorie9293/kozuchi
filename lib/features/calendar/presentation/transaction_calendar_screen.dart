import 'package:flutter/material.dart';

import '../../../domain/models/expense_entry.dart';
import '../domain/calendar_service.dart';
import '../domain/day_expense_summary.dart';
import '../domain/month_calendar.dart';
import '../../../core/infrastructure/cloud_sync_service.dart';
import '../../../core/infrastructure/supabase_provider.dart';
import '../../../domain/services/supabase_expense_repository.dart';
import 'calendar_app_keys.dart';

DateTime _defaultClock() => DateTime.now();

/// 取引カレンダー画面。
///
/// 支出エントリを月単位のカレンダーに可視化する。
/// テスト時は [entriesOverride] / [entriesLoader] / [clock] で
/// 外部依存を差し替え可能。
class TransactionCalendarScreen extends StatefulWidget {
  /// 試練用。指定時はロードせずこのエントリ群を表示する。
  final List<ExpenseEntry>? entriesOverride;

  /// 試練用。指定時はこれを await してエントリ群を取得する。
  final Future<List<ExpenseEntry>> Function()? entriesLoader;

  /// 現在時刻の取得（今日強調・未来月制限に使用）。既定: [DateTime.now]
  final DateTime Function() clock;

  /// 表示を開始する年月。既定: [clock] の年月。
  final int? initialYear;
  final int? initialMonth;

  const TransactionCalendarScreen({
    super.key,
    this.entriesOverride,
    this.entriesLoader,
    this.clock = _defaultClock,
    this.initialYear,
    this.initialMonth,
  });

  @override
  State<TransactionCalendarScreen> createState() =>
      _TransactionCalendarScreenState();
}

class _TransactionCalendarScreenState extends State<TransactionCalendarScreen> {
  static const _calendarService = CalendarService();

  bool _isLoading = true;
  List<ExpenseEntry> _entries = const [];
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    final now = widget.clock();
    _year = widget.initialYear ?? now.year;
    _month = widget.initialMonth ?? now.month;
    if (widget.entriesOverride != null) {
      _entries = widget.entriesOverride!;
      _isLoading = false;
    } else {
      _loadEntries();
    }
  }

  Future<void> _loadEntries() async {
    try {
      final List<ExpenseEntry> entries;
      if (widget.entriesLoader != null) {
        entries = await widget.entriesLoader!();
      } else {
        final repository = SupabaseExpenseRepository(
          cloudStore: CloudSyncService(client: SupabaseProvider.client),
          userIdProvider: () => SupabaseProvider.currentUserId,
        );
        entries = await repository.getEntries(
          start: DateTime(2000, 1, 1),
          end: DateTime(2100, 12, 31),
        );
      }
      if (!mounted) return;
      setState(() => _entries = entries);
    } catch (_) {
      // ロード失敗時は空リストでフォールバック
      if (!mounted) return;
      setState(() => _entries = const []);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  MonthCalendar get _calendar => _calendarService.build(
        entries: _entries,
        year: _year,
        month: _month,
      );

  bool get _isCurrentMonth {
    final now = widget.clock();
    return _calendarService.isCurrentMonth(year: _year, month: _month, now: now);
  }

  void _shift(int deltaMonths) {
    final shifted = _calendarService.shiftMonth(
      year: _year,
      month: _month,
      deltaMonths: deltaMonths,
    );
    setState(() {
      _year = shifted.year;
      _month = shifted.month;
    });
  }

  Future<void> _showDayDetail(DayExpenseSummary day) async {
    if (day.entryCount == 0) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: CalendarAppKeys.dayDetailDialog,
        title: Text(
          '${day.date.month}月${day.date.day}日 (${day.amountLabel})',
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: day.entries.length,
            itemBuilder: (context, index) {
              final entry = day.entries[index];
              final noteText =
                  entry.note == null || entry.note!.isEmpty ? '' : ' ${entry.note}';
              return ListTile(
                key: CalendarAppKeys.dayDetailRow(entry.id),
                dense: true,
                title: Text('${entry.category} ¥${entry.amount}'),
                subtitle: noteText.isEmpty ? null : Text(entry.note!),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(MonthCalendar calendar) {
    final maxDay = calendar.maxDay;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                const Text('月合計'),
                Text(
                  _amountLabel(calendar.totalAmount),
                  key: CalendarAppKeys.totalAmount,
                ),
              ],
            ),
            Column(
              children: [
                const Text('支出日数'),
                Text(
                  '${calendar.spendingDayCount}日',
                  key: CalendarAppKeys.spendingDays,
                ),
              ],
            ),
            Column(
              children: [
                const Text('最大日'),
                Text(
                  maxDay == null
                      ? '-'
                      : '${maxDay.date.day}日 ${_amountLabel(maxDay.totalAmount)}',
                  key: CalendarAppKeys.maxDay,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _amountLabel(int amount) {
    if (amount == 0) return '';
    final digits = amount.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final remaining = digits.length - i;
      buffer.write(digits[i]);
      if (remaining > 1 && (remaining - 1) % 3 == 0) buffer.write(',');
    }
    return '¥$buffer';
  }

  Widget _dayCell(DayExpenseSummary? day, DateTime now) {
    if (day == null) return const SizedBox.shrink();
    final isToday = now.year == day.date.year &&
        now.month == day.date.month &&
        now.day == day.date.day;
    final hasExpense = day.entryCount > 0;

    return InkWell(
      key: CalendarAppKeys.dayCell(day.date),
      onTap: hasExpense ? () => _showDayDetail(day) : null,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        decoration: BoxDecoration(
          border: isToday ? Border.all(color: Theme.of(context).primaryColor) : null,
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${day.date.day}'),
            if (hasExpense)
              Text(
                day.amountLabel,
                key: CalendarAppKeys.dayAmount(day.date),
                style: const TextStyle(fontSize: 10),
              ),
          ],
        ),
      ),
    );
  }

  Widget _calendarGrid(MonthCalendar calendar, DateTime now) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _summaryCard(calendar),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final label in '日月火水木金土'.split(''))
                Expanded(
                  child: Center(child: Text(label)),
                ),
            ],
          ),
          for (final week in calendar.weeks)
            Row(
              children: [
                for (final day in week)
                  Expanded(
                    child: _dayCell(day, now),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.clock();
    final calendar = _calendar;
    final isEmpty = calendar.isEmpty;

    return Scaffold(
      key: CalendarAppKeys.screen,
      appBar: AppBar(
        title: const Text('取引カレンダー'),
        actions: [
          IconButton(
            key: CalendarAppKeys.prevMonthButton,
            tooltip: '前月',
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _shift(-1),
          ),
          IconButton(
            key: CalendarAppKeys.nextMonthButton,
            tooltip: '翌月',
            icon: const Icon(Icons.chevron_right),
            // 当月表示時のみ無効化（未来月へは進めない）
            onPressed: _isCurrentMonth ? null : () => _shift(1),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    calendar.title,
                    key: CalendarAppKeys.monthLabel,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Expanded(
                  child: isEmpty
                      ? const Center(
                          child: Text(
                            'この月の支出はありません',
                            key: CalendarAppKeys.emptyMessage,
                          ),
                        )
                      : _calendarGrid(calendar, now),
                ),
              ],
            ),
    );
  }
}