import 'package:flutter/material.dart';

import 'package:kozuchi/features/tags/data/tag_repository.dart';
import 'package:kozuchi/features/tags/domain/models/expense_tag.dart';
import 'package:kozuchi/features/tags/presentation/tag_app_keys.dart';

/// タグの作成・改名・削除を行う管理画面。
///
/// [repository] で永続化先を差し替え可能（試練では SharedPreferences のモックを使用）。
class TagManagementScreen extends StatefulWidget {
  final TagRepository repository;

  /// 全期間の取引キーを返す関数。
  ///
  /// 未指定なら「使われていないタグ紐付けの整理」導線を出さない（従来挙動）。
  /// 指定時は画面末尾に整理用の項目を表示する。
  final Future<List<String>> Function()? orphanKeyLoader;

  const TagManagementScreen({
    super.key,
    this.repository = const TagRepository(),
    this.orphanKeyLoader,
  });

  @override
  State<TagManagementScreen> createState() => _TagManagementScreenState();
}

class _TagManagementScreenState extends State<TagManagementScreen> {
  List<ExpenseTag> _tags = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tags = await widget.repository.loadTags();
    if (!mounted) return;
    setState(() {
      _tags = tags;
      _isLoading = false;
    });
  }

  Future<void> _createTag() async {
    final name = await _showNameDialog(title: 'タグを作成');
    if (name == null) return;
    final updated = await widget.repository.createTag(name);
    if (!mounted) return;
    setState(() => _tags = updated);
  }

  Future<void> _renameTag(ExpenseTag tag) async {
    final name = await _showNameDialog(
      title: 'タグを改名',
      initialValue: tag.name,
    );
    if (name == null) return;
    final updated = await widget.repository.renameTag(tag.id, name);
    if (!mounted) return;
    setState(() => _tags = updated);
  }

  Future<void> _deleteTag(ExpenseTag tag) async {
    final updated = await widget.repository.deleteTag(tag.id);
    if (!mounted) return;
    setState(() => _tags = updated);
  }

  /// 孤児タグ紐付け（取引が存在しない紐付け）を整理する。
  ///
  /// 取引キーの取得に失敗した場合は何も削除せず、その旨を表示する。
  Future<void> _pruneOrphans() async {
    final loader = widget.orphanKeyLoader;
    if (loader == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: TagAppKeys.pruneOrphanDialog,
        title: const Text('使われていないタグ紐付けを整理'),
        content: const Text('取引が存在しない紐付けを削除します。よろしいですか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            key: TagAppKeys.pruneOrphanConfirmButton,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('整理する'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    List<String> keys;
    try {
      keys = await loader();
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('取引を取得できませんでした。整理は行っていません')),
      );
      return;
    }
    if (!mounted) return;

    final removed = await widget.repository.pruneOrphans(keys);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          removed > 0 ? '$removed件の紐付けを整理しました' : '整理する紐付けはありません',
        ),
      ),
    );
  }

  /// タグ名入力ダイアログ。確定時は名前、キャンセル時は null を返す。
  Future<String?> _showNameDialog({
    required String title,
    String initialValue = '',
  }) {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => _TagNameDialog(
        title: title,
        initialValue: initialValue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: TagAppKeys.managementScreen,
      appBar: AppBar(
        title: const Text('タグ管理'),
        actions: [
          IconButton(
            key: TagAppKeys.addButton,
            tooltip: 'タグを追加',
            icon: const Icon(Icons.add),
            onPressed: _createTag,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(child: _buildTagList()),
                if (widget.orphanKeyLoader != null) _buildPruneTile(),
              ],
            ),
    );
  }

  /// タグ一覧（空状態を含む）。
  Widget _buildTagList() {
    if (_tags.isEmpty) {
      return const Center(child: Text('タグがありません'));
    }
    return ListView.builder(
      itemCount: _tags.length,
      itemBuilder: (context, index) {
        final tag = _tags[index];
        return Semantics(
          label: 'タグ ${tag.name}',
          child: ListTile(
            key: TagAppKeys.listTile(tag.id),
            leading: CircleAvatar(
              radius: 10,
              backgroundColor: Color(tag.colorValue),
            ),
            title: Text(tag.name),
            onTap: () => _renameTag(tag),
            trailing: IconButton(
              key: TagAppKeys.deleteButton(tag.id),
              tooltip: '${tag.name} を削除',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _deleteTag(tag),
            ),
          ),
        );
      },
    );
  }

  /// 孤児タグ紐付けの整理導線（loader 指定時のみ）。
  Widget _buildPruneTile() {
    return SafeArea(
      top: false,
      child: ListTile(
        key: TagAppKeys.pruneOrphanTile,
        leading: const Icon(Icons.cleaning_services_outlined),
        title: const Text('使われていないタグ紐付けを整理'),
        subtitle: const Text('削除した取引に残ったタグ紐付けを取り除きます'),
        onTap: _pruneOrphans,
      ),
    );
  }
}

/// タグ名の入力ダイアログ本体。
///
/// [TextEditingController] の破棄をダイアログ自身のライフサイクルに閉じるため、
/// 独立した [StatefulWidget] としている（呼び出し側で即 dispose すると
/// 退出アニメーション中の参照で「used after being disposed」になる）。
class _TagNameDialog extends StatefulWidget {
  final String title;
  final String initialValue;

  const _TagNameDialog({
    required this.title,
    this.initialValue = '',
  });

  @override
  State<_TagNameDialog> createState() => _TagNameDialogState();
}

class _TagNameDialogState extends State<_TagNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: TagAppKeys.nameField,
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'タグ名'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          key: TagAppKeys.saveButton,
          onPressed: () {
            final text = _controller.text.trim();
            if (text.isEmpty) return;
            Navigator.of(context).pop(text);
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
