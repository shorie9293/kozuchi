import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';
import 'package:kozuchi/features/csv_import/domain/csv_import_service.dart';
import 'package:kozuchi/features/shared/presentation/kozuchi_app_keys.dart';

/// 銀行明細CSVインポート画面
///
/// CSVファイルを選択 → 突合（[CsvImportService.previewCsv]）→ 永続化する。
/// 重複なし・照合可能なら従来通り即時に取り込み、
/// 重複あり／照合不能のときだけ取込前の確認カードを挟む。
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

  /// 取込前の確認が必要な時だけ保持する突合結果
  CsvImportPreview? _preview;

  /// 「重複も取り込む」の選択状態
  bool _includeDuplicates = false;

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

  /// CSV選択 → 突合。判断が要らなければ即時取込、要るなら確認カードを出す。
  Future<void> _import() async {
    setState(() {
      _isImporting = true;
      _result = null;
      _preview = null;
      _includeDuplicates = false;
    });
    try {
      final picker = widget.pickCsvContent ?? _defaultPickCsvContent;
      final csv = await picker();
      if (!mounted) return;
      if (csv == null) {
        setState(() => _isImporting = false);
        return;
      }
      final preview = await _service.previewCsv(csv);
      if (!mounted) return;

      // 重複なし かつ 照合可能 → 従来通り即時取込（確認カードを挟まない）
      if (!preview.plan.hasDuplicates && preview.plan.canVerify) {
        final result = await _service.commitPreview(
          preview,
          includeDuplicates: false,
        );
        if (!mounted) return;
        setState(() {
          _result = result;
          _isImporting = false;
        });
        return;
      }

      // 判断が必要な時だけプレビューを保持（この時点では書き込みなし）
      setState(() {
        _preview = preview;
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

  /// プレビューを確定して取り込む
  Future<void> _commitPreview({bool allowUnverified = false}) async {
    final preview = _preview;
    if (preview == null) return;
    setState(() => _isImporting = true);
    try {
      final result = await _service.commitPreview(
        preview,
        includeDuplicates: _includeDuplicates,
        allowUnverified: allowUnverified,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _preview = null;
        _isImporting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isImporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('取り込みに失敗しました')),
      );
    }
  }

  /// プレビューを破棄する（何も書き込まない）
  void _cancelPreview() {
    setState(() {
      _preview = null;
      _includeDuplicates = false;
    });
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
            if (_preview != null) ...[
              const SizedBox(height: 20),
              _buildPreviewCard(colorScheme),
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

  /// 取込前の確認カード（重複あり／照合不能のときのみ表示）
  Widget _buildPreviewCard(ColorScheme colorScheme) {
    final preview = _preview!;
    final plan = preview.plan;
    final canVerify = plan.canVerify;

    return Container(
      key: KozuchiAppKeys.csvImport_previewCard,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '取り込み前の確認',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          if (canVerify) ...[
            Text(
              '新規 ${plan.freshCount}件',
              key: KozuchiAppKeys.csvImport_freshCountText,
              style: TextStyle(fontSize: 13, color: colorScheme.onSurface),
            ),
            const SizedBox(height: 4),
            Text(
              '重複 ${plan.duplicateCount}件',
              key: KozuchiAppKeys.csvImport_duplicateCountText,
              style: TextStyle(fontSize: 13, color: colorScheme.error),
            ),
            const SizedBox(height: 4),
            // Container の背景色下でも ListTile のインクが描けるよう Material で包む
            Material(
              type: MaterialType.transparency,
              child: CheckboxListTile(
                key: KozuchiAppKeys.csvImport_includeDuplicatesSwitch,
                value: _includeDuplicates,
                onChanged: _isImporting
                    ? null
                    : (value) =>
                        setState(() => _includeDuplicates = value ?? false),
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('重複も取り込む', style: TextStyle(fontSize: 13)),
              ),
            ),
          ] else ...[
            Text(
              '重複確認ができませんでした',
              key: KozuchiAppKeys.csvImport_unverifiedNotice,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: colorScheme.error,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '保存済みの取引を読み取れなかったため、重複を判定できていません。'
              '取り込むと重複が生じる可能性がある。',
              style: TextStyle(fontSize: 11, color: colorScheme.onSurface),
            ),
          ],
          if (preview.skippedCount > 0) ...[
            const SizedBox(height: 4),
            Text(
              'スキップ: ${preview.skippedCount}件',
              style: TextStyle(fontSize: 12, color: colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
          // 主ボタン: 照合できた時は重複スキップ取込、できていない時は書き込み0
          SemanticHelper.interactive(
            testId: 'btn_csvImport_confirm',
            label: '重複をスキップして取り込む',
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: KozuchiAppKeys.csvImport_confirmButton,
                // 照合できていない時は「重複をスキップ」できないため無効化する。
                // 押せてしまうとプレビューが消費され、上書き導線へ辿れなくなる。
                onPressed: (_isImporting || !canVerify)
                    ? null
                    : () => _commitPreview(),
                child: Text(
                  canVerify && _includeDuplicates
                      ? '重複も含めて取り込む'
                      : '重複をスキップして取り込む',
                ),
              ),
            ),
          ),
          // 照合できなかった時だけ出す明示的な上書き導線
          if (!canVerify) ...[
            const SizedBox(height: 8),
            SemanticHelper.interactive(
              testId: 'btn_csvImport_unverifiedOverride',
              label: '重複確認なしで取り込む',
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  key: KozuchiAppKeys.csvImport_unverifiedOverrideButton,
                  onPressed: _isImporting
                      ? null
                      : () => _commitPreview(allowUnverified: true),
                  child: const Text('重複確認なしで取り込む'),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          SemanticHelper.interactive(
            testId: 'btn_csvImport_cancelPreview',
            label: 'キャンセル',
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                key: KozuchiAppKeys.csvImport_cancelPreviewButton,
                onPressed: _isImporting ? null : _cancelPreview,
                child: const Text('キャンセル'),
              ),
            ),
          ),
        ],
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
          if (result.duplicateCount > 0) ...[
            const SizedBox(height: 8),
            Text(
              '重複スキップ: ${result.duplicateCount}件',
              style: TextStyle(color: colorScheme.error, fontSize: 13),
            ),
          ],
          if (!result.canVerify && result.importedCount > 0) ...[
            const SizedBox(height: 8),
            Text(
              '重複確認なしで取り込みました',
              style: TextStyle(color: colorScheme.error, fontSize: 13),
            ),
          ],
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
