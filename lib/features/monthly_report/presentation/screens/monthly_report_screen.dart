import 'package:flutter/material.dart';
import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/domain/services/expense_repository.dart';
import 'package:kozuchi/domain/services/expense_repository_impl.dart';
import 'package:kozuchi/features/monthly_report/domain/monthly_report.dart';
import 'package:kozuchi/features/monthly_report/domain/monthly_report_period.dart';
import 'package:kozuchi/features/monthly_report/domain/monthly_report_service.dart';
import 'package:kozuchi/features/monthly_report/presentation/widgets/monthly_report_card_view.dart';
import 'package:kozuchi/features/monthly_report/presentation/widgets/report_card_capture.dart';
import 'package:kozuchi/features/shared/presentation/kozuchi_app_keys.dart';

/// 月次家計レポート画面
///
/// 選択月のレポートを表示し、カード画像としての保存・共有を行う。
/// リポジトリ・キャプチャ・エクスポータはすべてテスト注入可能。
class MonthlyReportScreen extends StatefulWidget {
  final ExpenseRepository? repository;
  final ReportCardCapture? capture;
  final ReportCardExporter? exporter;

  /// 初期表示月（null なら現在月）
  final DateTime? initialMonth;

  const MonthlyReportScreen({
    super.key,
    this.repository,
    this.capture,
    this.exporter,
    this.initialMonth,
  });

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  final GlobalKey _boundaryKey = GlobalKey(debugLabel: 'monthlyReportCard');

  late MonthlyReportPeriod _period;
  MonthlyReport? _report;
  bool _isLoading = false;
  String? _error;

  ExpenseRepository get _repository =>
      widget.repository ?? InMemoryExpenseRepository();
  ReportCardCapture get _capture =>
      widget.capture ?? const RepaintBoundaryCapture();
  ReportCardExporter get _exporter =>
      widget.exporter ?? const SharePlusReportCardExporter();

  @override
  void initState() {
    super.initState();
    _period = MonthlyReportPeriod.fromDate(widget.initialMonth ?? DateTime.now());
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final current = await _repository.getEntries(
        start: _period.start,
        end: _period.end,
      );
      final prevPeriod = _period.previous;
      final previous = await _repository.getEntries(
        start: prevPeriod.start,
        end: prevPeriod.end,
      );
      final report = MonthlyReportService.build(
        period: _period,
        transactions: _toTransactions(current),
        previousMonthTransactions: _toTransactions(previous),
      );
      if (!mounted) return;
      setState(() {
        _report = report;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// ExpenseEntry を TransactionModel に変換する（ExpenseEntry は支出のみ・amount 正）
  static List<TransactionModel> _toTransactions(List<ExpenseEntry> entries) {
    return entries
        .map((e) => TransactionModel(
              amount: -e.amount.abs(),
              purpose: e.note ?? '',
              category: e.category,
              datetime: e.date.toIso8601String(),
            ))
        .toList();
  }

  Future<void> _goPrevious() async {
    setState(() => _period = _period.previous);
    await _load();
  }

  Future<void> _goNext() async {
    setState(() => _period = _period.next);
    await _load();
  }

  bool get _isFutureMonth {
    final now = DateTime.now();
    final nowPeriod = MonthlyReportPeriod(year: now.year, month: now.month);
    return _period.year > nowPeriod.year ||
        (_period.year == nowPeriod.year && _period.month > nowPeriod.month);
  }

  Future<void> _share() async {
    final report = _report;
    if (report == null) return;
    final png = await _capture.capture(_boundaryKey);
    if (!mounted) return;
    if (png == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('画像の生成に失敗しました')),
      );
      return;
    }
    await _exporter.export(
      png: png,
      fileName:
          'kozuchi_report_${_period.year}-${_period.month.toString().padLeft(2, '0')}.png',
      text: report.shareText,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_period.label),
        actions: [
          IconButton(
            key: KozuchiAppKeys.monthlyReportPrevMonth,
            icon: const Icon(Icons.chevron_left),
            tooltip: '前月',
            onPressed: _isLoading ? null : _goPrevious,
          ),
          IconButton(
            key: KozuchiAppKeys.monthlyReportNextMonth,
            icon: const Icon(Icons.chevron_right),
            tooltip: '次月',
            onPressed: _isLoading || _isFutureMonth ? null : _goNext,
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('読み込みに失敗しました'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _load,
              child: const Text('再試行'),
            ),
          ],
        ),
      );
    }
    final report = _report;
    if (report == null) {
      return const SizedBox.shrink();
    }
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            RepaintBoundary(
              key: _boundaryKey,
              child: KeyedSubtree(
                key: KozuchiAppKeys.monthlyReportCard,
                child: MonthlyReportCardView(report: report),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: KozuchiAppKeys.monthlyReportShareButton,
                icon: const Icon(Icons.ios_share),
                label: const Text('画像として保存・共有'),
                onPressed: _share,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
