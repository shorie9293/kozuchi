import 'package:flutter/material.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';

import 'package:kozuchi/features/auto_backup/data/auto_backup_store.dart';
import 'package:kozuchi/features/auto_backup/domain/auto_backup_policy.dart';
import 'package:kozuchi/features/auto_backup/domain/auto_backup_presenter.dart';
import 'package:kozuchi/features/auto_backup/domain/auto_backup_restorer.dart';
import 'package:kozuchi/features/auto_backup/domain/auto_backup_sharer.dart';
import 'package:kozuchi/features/auto_backup/presentation/auto_backup_keys.dart';

/// 自動バックアップの閲覧・復元・共有画面。
///
/// 復元／共有は注入された実装がある時だけ導線を出す
/// （未注入なら押せない導線を見せない）。例外は画面で握る。
class AutoBackupScreen extends StatefulWidget {
  final AutoBackupStore store;
  final AutoBackupPolicy policy;
  final AutoBackupRestorer? restorer;
  final AutoBackupSharer? sharer;

  /// 「今すぐバックアップ」の実行（未指定なら導線を出さない）。
  final Future<void> Function()? onBackupNow;

  final DateTime Function()? now;

  const AutoBackupScreen({
    super.key,
    required this.store,
    this.policy = const AutoBackupPolicy(),
    this.restorer,
    this.sharer,
    this.onBackupNow,
    this.now,
  });

  @override
  State<AutoBackupScreen> createState() => _AutoBackupScreenState();
}

class _AutoBackupScreenState extends State<AutoBackupScreen> {
  final Map<String, String?> _contents = <String, String?>{};
  List<AutoBackupRow>? _rows;
  bool _busy = false;

  AutoBackupPresenter get _presenter =>
      AutoBackupPresenter(keep: widget.policy.keep);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final entries = await widget.store.list();
      final contents = <String, String?>{};
      for (final entry in entries) {
        contents[entry.fileName] = await widget.store.read(entry.fileName);
      }
      if (!mounted) return;
      setState(() {
        _contents
          ..clear()
          ..addAll(contents);
        _rows = _presenter.buildRows(entries: entries, contents: contents);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _contents.clear();
        _rows = const <AutoBackupRow>[];
      });
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _restore(String fileName) async {
    final restorer = widget.restorer;
    if (restorer == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: AutoBackupAppKeys.confirmDialog,
        title: const Text('復元の確認'),
        content: const Text(
          'このバックアップから復元しますか？現在のデータは先に自動バックアップされます',
        ),
        actions: [
          TextButton(
            key: AutoBackupAppKeys.cancelButton,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            key: AutoBackupAppKeys.confirmButton,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('復元する'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final result = await restorer.restore(fileName);
      _notify(result.message ?? (result.ok ? '復元しました' : '復元できませんでした'));
    } catch (_) {
      _notify('復元に失敗しました');
    }
    await _reload();
  }

  Future<void> _share(String fileName) async {
    final sharer = widget.sharer;
    if (sharer == null) return;
    final json = _contents[fileName];
    if (json == null) {
      _notify('バックアップを読み出せませんでした');
      return;
    }
    try {
      await sharer.share(fileName, json);
    } catch (_) {
      _notify('共有に失敗しました');
    }
  }

  Future<void> _backupNow() async {
    final action = widget.onBackupNow;
    if (action == null || _busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      _notify('バックアップに失敗しました');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return Scaffold(
      key: AutoBackupAppKeys.screen,
      appBar: AppBar(title: const Text('自動バックアップ')),
      body: rows == null
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(context, rows),
      bottomNavigationBar: widget.onBackupNow == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SemanticHelper.interactive(
                  testId: 'auto_backup_btn_now',
                  label: '今すぐバックアップ',
                  child: FilledButton.icon(
                    key: AutoBackupAppKeys.backupNowButton,
                    onPressed: _busy ? null : _backupNow,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('今すぐバックアップ'),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildBody(BuildContext context, List<AutoBackupRow> rows) {
    if (rows.isEmpty) {
      return Center(
        child: Text(
          'バックアップはまだありません',
          key: AutoBackupAppKeys.emptyText,
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView(
      key: AutoBackupAppKeys.list,
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            _presenter.retentionLabel(rows.length),
            key: AutoBackupAppKeys.retentionText,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        for (final row in rows) _buildRow(context, row),
      ],
    );
  }

  Widget _buildRow(BuildContext context, AutoBackupRow row) {
    final fileName = row.entry.fileName;
    final restorer = widget.restorer;
    final sharer = widget.sharer;
    final showRestore = restorer != null && row.restorable;
    final showShare = sharer != null;

    return ListTile(
      key: AutoBackupAppKeys.row(fileName),
      title: Text(row.displayLabel),
      subtitle: Text(fileName),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showRestore)
            SemanticHelper.interactive(
              testId: 'auto_backup_btn_restore',
              label: '${row.dateLabel}の世代から復元',
              child: IconButton(
                key: AutoBackupAppKeys.restoreButton(fileName),
                icon: const Icon(Icons.restore),
                tooltip: '復元',
                onPressed: () => _restore(fileName),
              ),
            ),
          if (showShare)
            SemanticHelper.interactive(
              testId: 'auto_backup_btn_share',
              label: '${row.dateLabel}の世代を共有',
              child: IconButton(
                key: AutoBackupAppKeys.shareButton(fileName),
                icon: const Icon(Icons.ios_share),
                tooltip: '共有',
                onPressed: () => _share(fileName),
              ),
            ),
        ],
      ),
    );
  }
}
