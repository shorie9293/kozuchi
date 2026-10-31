import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:kozuchi/core/crash/crash_log_entry.dart';
import 'package:kozuchi/core/crash/crash_log_repository.dart';
import 'package:kozuchi/core/crash/crash_log_service.dart';

/// 端末内に溜まったクラッシュ記録を確認・共有する画面。
///
/// 送信は行わず「クリップボードへコピー」だけを提供する（外部通信なし）。
class CrashLogScreen extends StatefulWidget {
  const CrashLogScreen({super.key, required this.repository});

  /// 記録の読み出し元。既定は端末内ファイル実装を main 側で注入する。
  final CrashLogRepository repository;

  static const Key screenKey = Key('crash_log_screen');
  static const Key summaryKey = Key('crash_log_summary');
  static const Key listKey = Key('crash_log_list');
  static const Key copyButtonKey = Key('crash_log_copy');
  static const Key emptyKey = Key('crash_log_empty');

  @override
  State<CrashLogScreen> createState() => _CrashLogScreenState();
}

class _CrashLogScreenState extends State<CrashLogScreen> {
  List<CrashLogEntry>? _entries;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await widget.repository.loadAll();
    if (!mounted) return;
    setState(() => _entries = loaded);
  }

  String _buildCopyText(List<CrashLogEntry> entries) {
    final summary = summarize(entries) ?? '';
    final buffer = StringBuffer()
      ..writeln('=== kozuchi 不具合記録 ===')
      ..writeln(summary)
      ..writeln('---');
    for (final entry in recent(entries, limit: entries.length)) {
      buffer
        ..writeln('[${entry.timeLabel}] ${entry.kind.label}: ${entry.message}')
        ..writeln(entry.stackTop)
        ..writeln('---');
    }
    return buffer.toString();
  }

  Future<void> _copy(List<CrashLogEntry> entries) async {
    try {
      await Clipboard.setData(ClipboardData(text: _buildCopyText(entries)));
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('クリップボードへコピーしました')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('コピーに失敗しました')),
      );
    }
  }

  Future<void> _clear() async {
    await widget.repository.clear();
    if (!mounted) return;
    setState(() => _entries = const <CrashLogEntry>[]);
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    return Scaffold(
      key: CrashLogScreen.screenKey,
      appBar: AppBar(
        title: const Text('不具合の報告'),
        actions: [
          if (entries != null && entries.isNotEmpty)
            IconButton(
              tooltip: '記録を消去',
              icon: const Icon(Icons.delete_outline),
              onPressed: _clear,
            ),
        ],
      ),
      body: entries == null
          ? const Center(child: CircularProgressIndicator())
          : entries.isEmpty
              ? _buildEmpty()
              : _buildBody(entries),
    );
  }

  Widget _buildEmpty() {
    return Center(
      key: CrashLogScreen.emptyKey,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, size: 48),
            const SizedBox(height: 12),
            Text(
              '記録された不具合はありません',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'アプリが異常終了したとき、ここに記録が残ります。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(List<CrashLogEntry> entries) {
    final summary = summarize(entries);
    final shown = recent(entries, limit: entries.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                summary ?? '',
                key: CrashLogScreen.summaryKey,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Semantics(
                button: true,
                label: 'クリップボードへコピー',
                child: OutlinedButton.icon(
                  key: CrashLogScreen.copyButtonKey,
                  onPressed: () => _copy(entries),
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  label: const Text('クリップボードへコピー'),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            key: CrashLogScreen.listKey,
            itemCount: shown.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final entry = shown[index];
              return ListTile(
                dense: true,
                title: Text(
                  entry.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${entry.timeLabel}・${entry.kind.label}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
