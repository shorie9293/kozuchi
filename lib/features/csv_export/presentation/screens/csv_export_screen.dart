import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kozuchi/features/csv_export/data/csv_export_service.dart';
import 'package:kozuchi/features/csv_export/data/drive_upload_service.dart';

/// CSVエクスポート画面
///
/// 日付範囲を選択し、取引データをCSV形式でエクスポートする。
/// - 日付範囲ピッカー（開始日〜終了日）
/// - Export CSV ボタン
/// - ローディング状態表示
/// - エラーメッセージ表示
class CsvExportScreen extends StatefulWidget {
  final CsvExportService? service;
  final DriveUploadService? driveService;

  const CsvExportScreen({
    super.key,
    this.service,
    this.driveService,
  });

  @override
  State<CsvExportScreen> createState() => _CsvExportScreenState();
}

class _CsvExportScreenState extends State<CsvExportScreen> {
  late final CsvExportService _service;
  late final DriveUploadService _driveService;
  final _emailController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;
  bool _isSendingEmail = false;
  bool _isUploadingDrive = false;
  String? _errorMessage;
  String? _successMessage;
  String? _cachedCsvContent;
  String? _driveShareLink;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? CsvExportService();
    _driveService = widget.driveService ?? DriveUploadService();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
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

  /// CSVエクスポートを実行
  Future<void> _exportCsv() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
      _driveShareLink = null;
    });

    try {
      final csvData = await _service.exportCsv(
        startDate: _startDate,
        endDate: _endDate,
      );
      _cachedCsvContent = csvData;

      // CSVをファイルに保存
      final dir = Directory.systemTemp;
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final file = File('${dir.path}/kozuchi_export_$timestamp.csv');
      await file.writeAsString(csvData);

      if (mounted) {
        setState(() {
          _isLoading = false;
          _successMessage = 'CSVを保存しました: ${file.path}';
        });
      }
    } on CsvExportException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.message;
        });
      }
    }
  }

  /// メールでCSVを送信
  Future<void> _sendEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'メールアドレスを入力してください';
      });
      return;
    }

    setState(() {
      _isSendingEmail = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final result = await _service.sendCsvByEmail(
        email: email,
        startDate: _startDate,
        endDate: _endDate,
      );

      if (mounted) {
        setState(() {
          _isSendingEmail = false;
          _successMessage = result['message']?.toString() ??
              'メールを送信しました';
        });
      }
    } on CsvExportException catch (e) {
      if (mounted) {
        setState(() {
          _isSendingEmail = false;
          _errorMessage = e.message;
        });
      }
    }
  }

  /// Google DriveにCSVをアップロード
  Future<void> _uploadToDrive() async {
    // CSVが未エクスポートなら先にエクスポート
    if (_cachedCsvContent == null) {
      setState(() {
        _errorMessage = '先に「CSVをエクスポート」を実行してください';
      });
      return;
    }

    setState(() {
      _isUploadingDrive = true;
      _errorMessage = null;
      _successMessage = null;
      _driveShareLink = null;
    });

    try {
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final result = await _driveService.uploadCsv(
        _cachedCsvContent!,
        filename: 'kozuchi_export_$timestamp.csv',
      );

      if (mounted) {
        setState(() {
          _isUploadingDrive = false;
          _driveShareLink = result.webViewLink;
          _successMessage = 'Driveにアップロードしました';
        });
        // 共有リンクをクリップボードにコピー
        if (result.webViewLink.isNotEmpty) {
          await Clipboard.setData(ClipboardData(text: result.webViewLink));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('共有リンクをコピーしました'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } on DriveUploadException catch (e) {
      if (mounted) {
        setState(() {
          _isUploadingDrive = false;
          _errorMessage = e.message;
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
      body: Padding(
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
                label: Text(_isLoading ? 'エクスポート中...' : 'CSVをエクスポート'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── メール共有セクション ──
            const Divider(height: 32),
            Text(
              'メールで共有',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),

            // メールアドレス入力
            TextField(
              key: const Key('csvExport_emailField'),
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              enabled: !_isSendingEmail,
              decoration: const InputDecoration(
                hintText: '送信先のメールアドレス',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            // メール送信ボタン
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                key: const Key('csvExport_emailSendButton'),
                onPressed: _isSendingEmail ? null : _sendEmail,
                icon: _isSendingEmail
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          key: Key('csvExport_emailLoadingIndicator'),
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send),
                label: Text(_isSendingEmail ? '送信中...' : 'メールで送信'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.secondary,
                  foregroundColor: theme.colorScheme.onSecondary,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Drive共有セクション ──
            const Divider(height: 32),
            Text(
              'Google Driveで共有',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),

            // Driveアップロードボタン
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                key: const Key('csvExport_driveUploadButton'),
                onPressed: (_isUploadingDrive || _cachedCsvContent == null)
                    ? null
                    : _uploadToDrive,
                icon: _isUploadingDrive
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          key: Key('csvExport_driveLoadingIndicator'),
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.cloud_upload),
                label: Text(_isUploadingDrive ? 'アップロード中...' : 'Driveに保存'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.tertiary,
                  foregroundColor: theme.colorScheme.onTertiary,
                ),
              ),
            ),

            // 共有リンク表示
            if (_driveShareLink != null) ...[
              const SizedBox(height: 12),
              Card(
                key: const Key('csvExport_driveLinkCard'),
                color: theme.colorScheme.tertiaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.link,
                              color: theme.colorScheme.onTertiaryContainer,
                              size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '共有リンク（コピー済み）',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onTertiaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _driveShareLink!,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onTertiaryContainer
                              .withAlpha(180),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],

            if (_cachedCsvContent == null) ...[
              const SizedBox(height: 4),
              Text(
                '※ Driveに保存するには、先に「CSVをエクスポート」を実行してください',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(120),
                ),
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: 16),

            // 説明テキスト
            Text(
              '選択した期間の取引データをCSV形式で出力します。\n'
              '期間を指定しない場合は、全期間のデータが出力されます。',
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
