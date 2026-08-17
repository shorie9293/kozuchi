import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';
import 'package:kozuchi/features/csv_import/domain/csv_import_service.dart';
import 'package:kozuchi/features/shared/presentation/kozuchi_app_keys.dart';

/// 銀行明細CSVインポート画面
///
/// CSVファイルを選択 → パース → ローカル取引として永続化する。
/// ファイル選択は [pickCsvContent] で注入可能（テスト容易性のため）。
class CsvImportScreen extends StatefulWidget {
  final CsvImportService? service;

  /// CSV文字列を返すピッカー。null の場合は file_picker を使用する。
  final Future<String?> Function()? pickCsvContent;

  const CsvImportScreen({super.key, this.service, this.pickCsvContent});

  @override
  State<CsvImportScreen> createState() => _CsvImportScreenState();
}

class _CsvImportScreenState extends State<CsvImportScreen> {
  late final CsvImportService _service;
  bool _isImporting = false;
  CsvImportResult? _result;
  String? _fileName;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? const CsvImportService();
  }

  /// デフォルトのファイル選択（file_picker を使用）
  Future<String?> _defaultPickCsvContent() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'txt'],
    );
    if (picked == null || picked.files.isEmpty) return null;
    final file = picked.files.single;
    _fileName = file.name;
    final path = file.path;
    if (path != null) {
      return await File(path).readAsString();
    }
    final bytes = file.bytes;
    if (bytes != null) return utf8.decode(bytes, allowMalformed: true);
    return null;
  }

  Future<void> _import() async {
    setState(() {
      _isImporting = true;
      _result = null;
    });
    try {
      final picker = widget.pickCsvContent ?? _defaultPickCsvContent;
      final csv = await picker();
      if (!mounted) return;
      if (csv == null) {
        setState(() => _isImporting = false);
        return;
      }
      final result = await _service.importCsv(csv);
      if (!mounted) return;
      setState(() {
        _result = result;
        _isImporting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isImporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSVの読み込みに失敗しました')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      key: KozuchiAppKeys.csvImportScreen,
      appBar: AppBar(title: const Text('銀行明細の取り込み')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Text('📥', style: TextStyle(fontSize: 24)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '銀行の明細をCSVで取り込むと、収支がそのまま帳面に記される。'
                      '日付・摘要・金額の列を含むCSVに対応している。',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // ファイル選択ボタン
            SemanticHelper.interactive(
              testId: 'btn_csvImport_pick',
              label: 'CSVファイルを選択',
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  key: KozuchiAppKeys.csvImport_pickButton,
                  onPressed: _isImporting ? null : _import,
                  icon: _isImporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file),
                  label: Text(_isImporting ? '読み込み中…' : 'CSVファイルを選択'),
                ),
              ),
            ),
            if (_fileName != null) ...[
              const SizedBox(height: 8),
              Text(
                '選択: $_fileName',
                style: TextStyle(fontSize: 12, color: colorScheme.outline),
              ),
            ],
            if (_result != null) ...[
              const SizedBox(height: 20),
              _buildResultCard(colorScheme),
              if (_result!.transactions.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  '取り込んだ取引',
                  style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                ),
                const SizedBox(height: 8),
                Container(
                  key: KozuchiAppKeys.csvImport_importedList,
                  decoration: BoxDecoration(
                    border: Border.all(color: colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      for (final tx in _result!.transactions)
                        ListTile(
                          dense: true,
                          leading: Text(
                            tx.isIncome ? '💰' : '💸',
                          ),
                          title: Text(tx.purpose),
                          trailing: Text(
                            _formatAmount(tx.amount),
                            style: TextStyle(
                              color: tx.isIncome
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(ColorScheme colorScheme) {
    final result = _result!;
    return Container(
      key: KozuchiAppKeys.csvImport_resultCard,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('✅', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                '取り込みました: ${result.importedCount}件',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
          if (result.skippedCount > 0) ...[
            const SizedBox(height: 8),
            Text(
              'スキップ: ${result.skippedCount}件',
              key: KozuchiAppKeys.csvImportErrorText,
              style: TextStyle(color: colorScheme.error, fontSize: 13),
            ),
          ],
          if (result.errorMessages.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final msg in result.errorMessages.take(5))
              Text(
                msg,
                style: TextStyle(fontSize: 11, color: colorScheme.error),
              ),
          ],
        ],
      ),
    );
  }

  String _formatAmount(int amount) {
    final absStr = amount.abs().toString().replaceAllMapped(
          RegExp(r'(\d)(?=(?:\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    return amount >= 0 ? '+¥$absStr' : '-¥$absStr';
  }
}
