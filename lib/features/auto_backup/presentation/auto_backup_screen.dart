import 'package:flutter/material.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';

import 'package:kozuchi/features/auto_backup/data/auto_backup_status_store.dart';
import 'package:kozuchi/features/auto_backup/data/auto_backup_store.dart';
import 'package:kozuchi/features/auto_backup/domain/auto_backup_policy.dart';
import 'package:kozuchi/features/auto_backup/domain/auto_backup_presenter.dart';
import 'package:kozuchi/features/auto_backup/domain/auto_backup_restorer.dart';
import 'package:kozuchi/features/auto_backup/domain/auto_backup_sharer.dart';
import 'package:kozuchi/features/auto_backup/domain/auto_backup_status.dart';
import 'package:kozuchi/features/auto_backup/presentation/auto_backup_keys.dart';
import 'package:kozuchi/features/backup/data/backup_repository.dart';
import 'package:kozuchi/features/backup/domain/backup_service.dart';
import 'package:kozuchi/features/backup/domain/restore_preview.dart';

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

  /// 自動バックアップの状態の読み出し元（null なら状態表示を出さない）。
  final AutoBackupStatusStore? statusStore;

  /// 復元前プレビューの突合先（null ならプレビューを出さない）。
  final BackupRepository? backupRepository;

  final DateTime Function()? now;

  const AutoBackupScreen({
    super.key,
    required this.store,
    this.policy = const AutoBackupPolicy(),
    this.restorer,
    this.sharer,
    this.onBackupNow,
    this.statusStore,
    this.backupRepository,
    this.now,
  });

  @override
  State<AutoBackupScreen> createState() => _AutoBackupScreenState();
}

class _AutoBackupScreenState extends State<AutoBackupScreen> {
  final Map<String, String?> _contents = <String, String?>{};
  List<AutoBackupRow>? _rows;
  AutoBackupStatus? _status;
  bool _busy = false;

  AutoBackupPresenter get _presenter =>
      AutoBackupPresenter(keep: widget.policy.keep);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<AutoBackupStatus?> _loadStatus() async {
    final statusStore = widget.statusStore;
    if (statusStore == null) return null;
    try {
      return await statusStore.load();
    } catch (_) {
      return null;
    }
  }

  Future<void> _reload() async {
    final status = await _loadStatus();
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
        _status = status;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _contents.clear();
        _rows = const <AutoBackupRow>[];
        _status = status;
      });
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// 復元前プレビューを組み立てる。失敗時は null（プレビュー非表示）。
  Future<RestorePreview?> _buildPreview(String fileName) async {
    final repository = widget.backupRepository;
    if (repository == null) return null;
    final json = _contents[fileName];
    if (json == null) return null;
    try {
      final bundle = BackupService().parse(json);
      final current = await repository.collect();
      return compose(bundle: bundle, existing: current.entries);
    } catch (_) {
      return null;
    }
  }

  Future<void> _restore(String fileName) async {
    final restorer = widget.restorer;
    if (restorer == null) return;

    final preview = await _buildPreview(fileName);
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: AutoBackupAppKeys.confirmDialog,
        title: const Text('復元の確認'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'このバックアップから復元しますか？現在のデータは先に自動バックアップされます',
              ),
              if (preview != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preview.summary,
                        key: AutoBackupAppKeys.restorePreview,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(preview.message),
                      ),
                      if (preview.samplesText != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(preview.samplesText!),
                        ),
                    ],
                  ),
                ),
            ],
          ),
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

  /// 失敗の警告バナー（未実行と毎回失敗を同じ見た目にしない）。
  Widget _failureBanner(BuildContext context, AutoBackupStatus status) {
    final attemptedAt = status.lastAttemptAt;
    final when = attemptedAt == null
        ? ''
        : '（最終試行 ${AutoBackupPresenter.formatDate(attemptedAt)}）';
    final reason = status.lastError;
    final onError = Theme.of(context).colorScheme.onErrorContainer;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        key: AutoBackupAppKeys.failureBanner,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '自動バックアップに失敗しています$when',
              style: TextStyle(color: onError, fontWeight: FontWeight.bold),
            ),
            if (reason != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(reason, style: TextStyle(color: onError)),
              ),
            if (widget.onBackupNow != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: AutoBackupAppKeys.retryButton,
                  onPressed: _busy ? null : _backupNow,
                  child: const Text('今すぐ実行'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<AutoBackupRow> rows) {
    final status = _status;
    final header = <Widget>[
      if (status?.lastSuccessAt != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(
            '最終成功 '
            '${AutoBackupPresenter.formatDate(status!.lastSuccessAt!)}',
            key: AutoBackupAppKeys.lastSuccessText,
          ),
        ),
      if (status?.hasFailed == true) _failureBanner(context, status!),
    ];

    if (rows.isEmpty) {
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ...header,
          if (status?.hasAttempted != true)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'バックアップはまだありません',
                  key: AutoBackupAppKeys.emptyText,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      );
    }
    return ListView(
      key: AutoBackupAppKeys.list,
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        ...header,
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
