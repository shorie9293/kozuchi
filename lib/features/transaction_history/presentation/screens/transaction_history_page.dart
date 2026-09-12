import 'package:flutter/material.dart';

import 'package:kozuchi/core/infrastructure/cloud_sync_service.dart';
import 'package:kozuchi/core/infrastructure/supabase_provider.dart';
import 'package:kozuchi/domain/services/supabase_expense_repository.dart';
import 'package:kozuchi/features/csv_import/data/local_transaction_repository.dart';
import 'package:kozuchi/features/transaction_filter/domain/models/transaction_filter.dart';
import 'package:kozuchi/features/transaction_filter/presentation/widgets/transaction_filter_bar.dart';
import 'package:kozuchi/features/transaction_history/presentation/state/transaction_controller.dart';
import 'package:kozuchi/features/transaction_history/presentation/widgets/transaction_list_widget.dart';
import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/tags/data/tag_repository.dart';
import 'package:kozuchi/features/tags/domain/models/tagged_transaction.dart';
import 'package:kozuchi/features/tags/presentation/screens/tag_management_screen.dart';
import 'package:kozuchi/features/tags/presentation/screens/tag_summary_screen.dart';
import 'package:kozuchi/features/tags/presentation/tag_app_keys.dart';
import 'package:kozuchi/features/tags/presentation/widgets/tag_assignment_dialog.dart';

/// 取引履歴一覧画面。
///
/// [TransactionFilterBar]（フィルタ）、[TransactionController]（データ取得）、
/// [TransactionListWidget]（リスト表示）を統合する。
///
/// ## 使い方
///
/// ```dart
/// Navigator.of(context).push(
///   MaterialPageRoute(builder: (_) => const TransactionHistoryPage()),
/// );
/// ```
///
/// テスト時は [controller] パラメータでモック済みの
/// [TransactionController] を注入可能。
class TransactionHistoryPage extends StatefulWidget {
  /// テスト用に注入可能なコントローラ。
  /// null の場合はデフォルトの [TransactionController] を生成する。
  final TransactionController? controller;

  /// ローカル取引（CSVインポート・定期取引）の保存先。
  /// null の場合は API 取引のみを表示する（従来動作）。
  final LocalTransactionRepository? localRepository;

  /// タグの永続化リポジトリ（試練で差し替え可能）。
  final TagRepository tagRepository;

  const TransactionHistoryPage({
    super.key,
    this.controller,
    this.localRepository,
    this.tagRepository = const TagRepository(),
  });

  @override
  State<TransactionHistoryPage> createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends State<TransactionHistoryPage> {
  late final TransactionController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
    } else {
      // 案B: 取引履歴は Supabase `expense_entries`（支出明細）を正とする。
      // 旧 localhost:8080 API（TransactionService）には依存しない。
      _controller = TransactionController(
        expenseRepository: SupabaseExpenseRepository(
          cloudStore: CloudSyncService(client: SupabaseProvider.client),
          userIdProvider: () => SupabaseProvider.currentUserId,
        ),
        initialFilter: _defaultFilter(),
        localRepository: widget.localRepository,
      );
      _ownsController = true;
    }
    _controller.fetchTransactions();
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  /// デフォルトのフィルタ値を生成する。
  ///
  /// - 種別: 全件
  /// - 開始日: 当月1日
  /// - 終了日: 本日
  TransactionFilter _defaultFilter() {
    final now = DateTime.now();
    return TransactionFilter(
      type: TransactionFilterType.all,
      startDate: DateTime(now.year, now.month, 1),
      endDate: DateTime(now.year, now.month, now.day),
    );
  }

  /// タグ定義と紐付けを読み込んでタグ別集計画面へ遷移する。
  Future<void> _openTagSummary(BuildContext context) async {
    final navigator = Navigator.of(context);
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => TagSummaryLoaderScreen(
          transactions: _controller.transactions,
          repository: widget.tagRepository,
        ),
      ),
    );
  }

  /// 取引にタグを割り当てる（タグ定義が無ければ案内を表示）。
  Future<void> _assignTags(TransactionModel transaction) async {
    final messenger = ScaffoldMessenger.of(context);
    final tags = await widget.tagRepository.loadTags();
    if (!mounted) return;
    if (tags.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('タグがありません。タグ管理から作成してください。')),
      );
      return;
    }

    final key = TaggedTransaction.keyOfTransaction(transaction);
    final selected = await widget.tagRepository.tagsFor(key);
    if (!mounted) return;

    final result = await showTagAssignmentDialog(
      context,
      tags: tags,
      selectedTagIds: selected,
    );
    if (result == null) return;
    await widget.tagRepository.assignTags(key, result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('取引履歴'),
        actions: [
          IconButton(
            key: TagAppKeys.historyTagManageButton,
            tooltip: 'タグ管理',
            icon: const Icon(Icons.sell_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    TagManagementScreen(repository: widget.tagRepository),
              ),
            ),
          ),
          IconButton(
            key: TagAppKeys.historyTagSummaryButton,
            tooltip: 'タグ別集計',
            icon: const Icon(Icons.label_outline),
            onPressed: () => _openTagSummary(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── フィルタバー（上部固定） ──
          TransactionFilterBar(
            initialFilter: _controller.filter,
            onChanged: (filter) => _controller.updateFilter(filter),
          ),
          // ── 取引一覧（残りの領域を占有） ──
          Expanded(
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) {
                return TransactionListWidget(
                  transactions: _controller.transactions,
                  isLoading: _controller.isLoading,
                  errorMessage: _controller.error,
                  onRetry: () => _controller.refetch(),
                  onTransactionTap: _assignTags,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
