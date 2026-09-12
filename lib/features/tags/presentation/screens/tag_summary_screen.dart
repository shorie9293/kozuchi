import 'package:flutter/material.dart';

import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/tags/data/tag_repository.dart';
import 'package:kozuchi/features/tags/domain/models/expense_tag.dart';
import 'package:kozuchi/features/tags/domain/tag_aggregation_service.dart';
import 'package:kozuchi/features/tags/presentation/tag_app_keys.dart';

/// タグ別集計・絞り込みの表示画面。
///
/// 純粋集計（[TagAggregationService]）の結果を一覧表示する。
/// 試練では [transactions]/[tags]/[assignments] を直接注入できる。
class TagSummaryScreen extends StatefulWidget {
  /// 集計対象の取引一覧
  final List<TransactionModel> transactions;

  /// タグ定義
  final List<ExpenseTag> tags;

  /// 取引キー → タグID列
  final Map<String, List<String>> assignments;

  /// 集計サービス（差し替え可能）
  final TagAggregationService service;

  const TagSummaryScreen({
    super.key,
    this.transactions = const [],
    this.tags = const [],
    this.assignments = const {},
    this.service = const TagAggregationService(),
  });

  @override
  State<TagSummaryScreen> createState() => _TagSummaryScreenState();
}

class _TagSummaryScreenState extends State<TagSummaryScreen> {
  String? _selectedTagId;

  TagAggregationResult get _result => widget.service.summarize(
        transactions: widget.transactions,
        assignments: widget.assignments,
        tags: widget.tags,
      );

  int _filteredCount(String? tagId) => widget.service
      .filterByTag(
        transactions: widget.transactions,
        assignments: widget.assignments,
        tagId: tagId,
      )
      .length;

  String _yen(int amount) {
    final formatted = amount.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    return '¥$formatted';
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return Scaffold(
      key: TagAppKeys.summaryScreen,
      appBar: AppBar(title: const Text('タグ別集計')),
      body: ListView(
        children: [
          _buildHeader(result),
          if (widget.tags.isEmpty && result.untaggedCount == 0)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('取引がありません')),
            ),
          for (final total in result.totals) _buildTagRow(total),
          _buildUntaggedRow(result),
        ],
      ),
    );
  }

  Widget _buildHeader(TagAggregationResult result) {
    final selected = _selectedTagId;
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'タグ ${result.totals.length}件 / 集計対象 ${widget.transactions.length}件',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              selected == null
                  ? 'タグを選ぶと絞り込み件数を確認できます'
                  : '選択中: ${_tagName(selected)} — ${_filteredCount(selected)}件',
            ),
            if (selected != null)
              TextButton(
                onPressed: () => setState(() => _selectedTagId = null),
                child: const Text('絞り込みを解除'),
              ),
          ],
        ),
      ),
    );
  }

  String _tagName(String tagId) {
    for (final tag in widget.tags) {
      if (tag.id == tagId) return tag.name;
    }
    return tagId;
  }

  Widget _buildTagRow(TagTotal total) {
    final selected = _selectedTagId == total.tagId;
    return Semantics(
      label: 'タグ集計 ${total.name}',
      child: ListTile(
        key: TagAppKeys.summaryRow(total.tagId),
        leading: CircleAvatar(
          radius: 10,
          backgroundColor: _tagColor(total.tagId),
        ),
        title: Text(total.name.isEmpty ? total.tagId : total.name),
        subtitle: Text(
          '${total.count}件・支出 ${_yen(total.expenseTotal)}'
          '${total.incomeTotal > 0 ? '・収入 ${_yen(total.incomeTotal)}' : ''}',
        ),
        selected: selected,
        onTap: () => setState(
          () => _selectedTagId = selected ? null : total.tagId,
        ),
      ),
    );
  }

  Color _tagColor(String tagId) {
    for (final tag in widget.tags) {
      if (tag.id == tagId) return Color(tag.colorValue);
    }
    return const Color(ExpenseTag.defaultColorValue);
  }

  Widget _buildUntaggedRow(TagAggregationResult result) {
    final selected = _selectedTagId == '';
    return ListTile(
      key: TagAppKeys.summaryUntaggedRow,
      leading: const Icon(Icons.label_off_outlined),
      title: const Text('タグなし'),
      subtitle: Text(
        '${result.untaggedCount}件・支出 ${_yen(result.untaggedExpenseTotal)}',
      ),
      selected: selected,
      onTap: () => setState(() => _selectedTagId = selected ? null : ''),
    );
  }
}

/// タグ定義・紐付けを [TagRepository] から読み込んで集計画面を表示するローダ。
///
/// 取引一覧と共に取引履歴画面から遷移する用途を想定する。
class TagSummaryLoaderScreen extends StatefulWidget {
  /// 集計対象の取引一覧
  final List<TransactionModel> transactions;

  /// 永続化リポジトリ
  final TagRepository repository;

  const TagSummaryLoaderScreen({
    super.key,
    this.transactions = const [],
    this.repository = const TagRepository(),
  });

  @override
  State<TagSummaryLoaderScreen> createState() => _TagSummaryLoaderScreenState();
}

class _TagSummaryLoaderScreenState extends State<TagSummaryLoaderScreen> {
  List<ExpenseTag> _tags = const [];
  Map<String, List<String>> _assignments = const {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tags = await widget.repository.loadTags();
    final assignments = await widget.repository.loadAssignments();
    if (!mounted) return;
    setState(() {
      _tags = tags;
      _assignments = assignments;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return TagSummaryScreen(
      transactions: widget.transactions,
      tags: _tags,
      assignments: _assignments,
    );
  }
}
