import 'package:flutter/material.dart';
import 'package:kozuchi/core/infrastructure/cloud_sync_service.dart';
import 'package:kozuchi/core/infrastructure/supabase_provider.dart';
import 'package:kozuchi/domain/services/expense_repository.dart';
import 'package:kozuchi/domain/services/supabase_expense_repository.dart';
import 'package:kozuchi/features/csv_export/data/csv_export_service.dart';
import 'package:kozuchi/features/csv_export/data/csv_file_sharer.dart';
import 'package:kozuchi/features/csv_export/data/drive_upload_service.dart';
import 'package:kozuchi/features/csv_export/domain/local_csv_export_service.dart';

/// CSVエクスポート画面
///
/// 端末が持つ支出明細（[ExpenseRepository]）から日付範囲でCSVを生成し、
/// 共有シートへ渡す。メール送信・Google Drive アップロードは
/// 旧 `localhost:8080` API 依存（現行構成に存在しない）ため UI から外した。
class CsvExportScreen extends StatefulWidget {
  /// 旧API用サービス。後方互換のため受け取るが、現行の出力経路では使わない。
  @Deprecated('旧 localhost:8080 API 用。現行の出力経路では未使用')
  final CsvExportService? service;

  /// 旧Drive API用サービス。同上。
  @Deprecated('旧 localhost:8080 API 用。現行の出力経路では未使用')
  final DriveUploadService? driveService;

  /// 支出明細の取得元。null なら Supabase（expense_entries）を遅延初期化する。
  final ExpenseRepository? expenseRepository;

  /// CSV共有の実行手段。null なら share_plus 実装を使う。
  final CsvFileSharer? sharer;

  const CsvExportScreen({
    super.key,
    @Deprecated('旧 localhost:8080 API 用。現行の出力経路では未使用')
    this.service,
    @Deprecated('旧 localhost:8080 API 用。現行の出力経路では未使用')
    this.driveService,
    this.expenseRepository,
    this.sharer,
  });

  @override
  State<CsvExportScreen> createState() => _CsvExportScreenState();
}

class _CsvExportScreenState extends State<CsvExportScreen> {
  final LocalCsvExportService _localService = const LocalCsvExportService();

  late final CsvFileSharer _sharer;
  ExpenseRepository? _repository;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  String? _shareErrorMessage;
  int _exportedCount = 0;

  @override
  void initState() {
    super.initState();
    _sharer = widget.sharer ?? const SharePlusCsvFileSharer();
  }

  /// 支出明細の取得元を取得する（[CsvExportScreen.expenseRepository] 注入優先）。
  ExpenseRepository _getRepository() {
    if (widget.expenseRepository != null) return widget.expenseRepository!;
    return _repository ??= SupabaseExpenseRepository(
      cloudStore: CloudSyncService(client: SupabaseProvider.client),
      userIdProvider: () => SupabaseProvider.currentUserId,
    );
  }

  /// 日付範囲ピッカーを開く
  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initialRange = _startDate != null && _endDate != null
        ? DateTimeRange(start: _startDate!, end: _endDate!)
        : DateTimeRange(
            start: _startDate ?? now.subtract(const Duration(days: 30)),
            end: _endDate ?? now,
          );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 1)),
      initialDateRange: initialRange,
      helpText: 'エクスポートする期間を選択',
      cancelText: 'キャンセル',
      confirmText: '決定',
      saveText: '決定',
      fieldStartHintText: '開始日',
      fieldEndHintText: '終了日',
    );

    if (picked != null && mounted) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _errorMessage = null;
        _successMessage = null;
      });
    }
  }

  /// 端末の明細からCSVを生成して共有する
  Future<void> _exportCsv() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
      _shareErrorMessage = null;
    });

    try {
      final now = DateTime.now();
      final repository = _getRepository();
      final entries = await repository.getEntries(
        start: _startDate ?? DateTime(2000, 1, 1),
        end: _endDate ?? now,
      );
      if (!mounted) return;

      final selected = _localService.selectEntries(
        entries,
        startDate: _startDate,
        endDate: _endDate,
      );
      final csv = _localService.buildCsv(
        entries: selected,
        startDate: _startDate,
        endDate: _endDate,
      );
      final fileName = _localService.fileNameFor(now);

      setState(() {
        _isLoading = false;
        _exportedCount = selected.length;
        _successMessage = selected.isEmpty
            ? 'この期間の取引はありません（ヘッダのみのCSVを生成しました）'
            : 'CSVを書き出しました（${selected.length}件）';
      });

      try {
        await _sharer.share(csv: csv, fileName: fileName);
      } catch (_) {
        if (mounted) {
          setState(() {
            _shareErrorMessage = '共有シートを開けませんでした（CSVの生成は完了しています）';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'CSVの書き出しに失敗しました: $e';
        });
      }
    }
  }

  /// 日付範囲の表示文字列を生成
  String get _dateRangeText {
    if (_startDate == null && _endDate == null) {
      return 'すべての期間';
    }
    final start = _startDate != null
        ? '${_startDate!.year}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}'
        : '指定なし';
    final end = _endDate != null
        ? '${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}'
        : '指定なし';
    return '$start 〜 $end';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      key: const Key('csvExportScreen'),
      appBar: AppBar(
        title: const Text('CSVエクスポート'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 日付範囲選択カード
            Card(
              key: const Key('csvExport_dateRangeCard'),
              elevation: 1,
              child: InkWell(
                key: const Key('csvExport_dateRangePicker'),
                onTap: _isLoading ? null : _pickDateRange,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.date_range, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'エクスポート期間',
                              style: theme.textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _dateRangeText,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // エラー表示
            if (_errorMessage != null) ...[
              Card(
                key: const Key('csvExport_errorCard'),
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: theme.colorScheme.onErrorContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 成功表示
            if (_successMessage != null) ...[
              Card(
                key: const Key('csvExport_successCard'),
                color: theme.colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline,
                          color: theme.colorScheme.onPrimaryContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _successMessage!,
                          key: const Key('csvExport_countText'),
                          style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 共有失敗の注意（生成自体は完了している）
            if (_shareErrorMessage != null) ...[
              Card(
                key: const Key('csvExport_shareErrorCard'),
                color: theme.colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: theme.colorScheme.onSecondaryContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _shareErrorMessage!,
                          style: TextStyle(
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Export CSV ボタン
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                key: const Key('csvExport_exportButton'),
                onPressed: _isLoading ? null : _exportCsv,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          key: Key('csvExport_loadingIndicator'),
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.file_download),
                label: Text(_isLoading ? '書き出し中...' : 'CSVを書き出す'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 説明テキスト
            Text(
              '端末に記録された支出明細からCSVを生成し、共有シートで受け渡します。\n'
              '期間を指定しない場合は、全期間のデータが出力されます。'
              '${_exportedCount > 0 ? '\n直近の書き出し: $_exportedCount件' : ''}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(150),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
