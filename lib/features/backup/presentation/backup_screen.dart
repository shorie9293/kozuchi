import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:kozuchi/features/backup/data/backup_file_io.dart';
import 'package:kozuchi/features/backup/data/backup_repository.dart';
import 'package:kozuchi/features/backup/domain/backup_models.dart';
import 'package:kozuchi/features/backup/domain/backup_service.dart';
import 'package:kozuchi/features/backup/presentation/backup_keys.dart';

/// バックアップと復元画面。
///
/// リポジトリ・入出力は外部依存として注入可能（テスト差し替え用）。
class BackupScreen extends StatefulWidget {
  final BackupRepository? repository;
  final BackupExporter? exporter;
  final BackupImporter? importer;
  final DateTime Function() now;

  const BackupScreen({
    super.key,
    this.repository,
    this.exporter,
    this.importer,
    this.now = DateTime.now,
  });

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  BackupBundle? _bundle;
  String? _error;

  // widget を late final で捕まえず、毎回 getter で参照する（陳腐化防止）。
  BackupRepository get _repository =>
      widget.repository ?? SharedPreferencesBackupRepository();
  BackupExporter get _exporter => widget.exporter ?? const SharePlusBackupExporter();
  BackupImporter get _importer => widget.importer ?? const FilePickerBackupImporter();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final bundle = await _repository.collect();
      if (!mounted) return;
      setState(() {
        _bundle = bundle;
        _error = null;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _bundle = null;
      });
    }
  }

  Future<void> _export() async {
    try {
      final bundle = await _repository.collect();
      final json = BackupService().exportJson(bundle);
      final fileName = BackupService.suggestedFileName(widget.now());
      await _exporter.export(json: json, fileName: fileName);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('バックアップを書き出しました')),
      );
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('バックアップの書き出しに失敗しました')),
      );
    }
  }

  Future<void> _restore() async {
    final json = await _importer.pickJson();
    if (json == null) return;

    final BackupBundle bundle;
    try {
      bundle = BackupService().parse(json);
    } on FormatException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('不正なバックアップファイルです')),
      );
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: BackupAppKeys.confirmRestoreDialog,
        title: const Text('復元の確認'),
        content: Text(
          '${bundle.entryCount}件のデータを復元します。\n現在の対象データは上書きされます。よろしいですか？',
        ),
        actions: [
          TextButton(
            key: BackupAppKeys.cancelRestoreButton,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            key: BackupAppKeys.confirmRestoreButton,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('復元する'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await _repository.restore(bundle);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.label)),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: BackupAppKeys.screen,
      appBar: AppBar(
        title: const Text(
          'バックアップと復元',
          key: BackupAppKeys.appBarTitle,
        ),
      ),
      body: _buildBody(context),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: BackupAppKeys.exportButton,
                  onPressed: _export,
                  icon: const Icon(Icons.ios_share),
                  label: const Text('エクスポート'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  key: BackupAppKeys.restoreButton,
                  onPressed: _restore,
                  icon: const Icon(Icons.restore),
                  label: const Text('復元'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_error != null) {
      return Center(child: Text('読み込みに失敗しました\n$_error'));
    }
    final bundle = _bundle;
    if (bundle == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (bundle.isEmpty) {
      return Center(
        child: Text(
          'バックアップ対象のデータがありません',
          key: BackupAppKeys.emptyText,
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView(
      key: BackupAppKeys.snapshotList,
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'バックアップ対象: ${bundle.entryCount}件',
          key: BackupAppKeys.entryCountText,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        for (final key in bundle.entries.keys.toList()..sort())
          ListTile(
            key: BackupAppKeys.row(key),
            dense: true,
            title: Text(key),
            subtitle: Text(_valuePreview(bundle.entries[key])),
          ),
      ],
    );
  }

  String _valuePreview(Object? value) {
    if (value is List) {
      return 'List<String>(${value.length}件)';
    }
    return jsonEncode(value);
  }
}
