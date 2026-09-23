import 'package:flutter/material.dart';

import 'package:kozuchi/core/infrastructure/cloud_sync_service.dart';
import 'package:kozuchi/core/infrastructure/supabase_provider.dart';
import 'package:kozuchi/domain/services/supabase_expense_repository.dart';
import 'package:kozuchi/features/calendar/presentation/calendar_app_keys.dart';
import 'package:kozuchi/features/calendar/presentation/transaction_calendar_screen.dart';
import 'package:kozuchi/features/csv_import/data/local_transaction_repository.dart';
import 'package:kozuchi/features/tags/domain/models/expense_tag.dart';
import 'package:kozuchi/features/transaction_filter/domain/models/transaction_filter.dart';
import 'package:kozuchi/features/transaction_filter/domain/models/transaction_query_result.dart';
import 'package:kozuchi/features/transaction_filter/domain/services/transaction_query_service.dart';
import 'package:kozuchi/features/transaction_filter/presentation/widgets/transaction_filter_bar.dart';
import 'package:kozuchi/features/transaction_filter/presentation/widgets/transaction_query_summary_bar.dart';
import 'package:kozuchi/features/receipt_viewer/presentation/screens/receipt_image_viewer_screen.dart';
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
/// [TransactionQueryService]（キーワード・カテゴリ・タグの純粋検索）、
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

  /// 読み込み済みのタグ定義（チップ表示用）。
  List<ExpenseTag> _tags = const [];

  /// 取引キー → タグID列の紐付け（検索用）。
  Map<String, List<String>> _tagAssignments = const {};

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
    _loadTags();
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  /// コントローラ更新（再取得・フィルタ変更）時にタグ紐付けを再読込する。
  void _onControllerChanged() {
    _loadTags();
  }

  /// タグ定義と紐付けを読み込む（失敗時は空でフォールバック）。
  Future<void> _loadTags() async {
    try {
      final results = await Future.wait([
        widget.tagRepository.loadTags(),
        widget.tagRepository.loadAssignments(),
      ]);
      if (!mounted) return;
      setState(() {
        _tags = results[0] as List<ExpenseTag>;
        _tagAssignments = results[1] as Map<String, List<String>>;
      });
    } catch (_) {
      // 失敗時は空でフォールバック
      if (!mounted) return;
      setState(() {
        _tags = const [];
        _tagAssignments = const {};
      });
    }
  }

  /// 現在の取引・フィルタ・タグ紐付けで検索し、結果（絞込一覧＋集計）を返す。
  TransactionQueryResult _queryResult() {
    return TransactionQueryService.query(
      transactions: _controller.transactions,
      filter: _controller.filter,
      tagAssignments: _tagAssignments,
    );
  }

  /// 取得済み取引からカテゴリの一意集合をソートして返す。
  List<String> _availableCategories() {
    final names = <String>{};
    for (final tx in _controller.transactions) {
      if (tx.category.isNotEmpty) names.add(tx.category);
    }
    final sorted = names.toList()..sort();
    return List.unmodifiable(sorted);
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
    await _loadTags();
  }

  /// 取引に紐づくレシート原本画像を閲覧する。
  void _openReceipt(TransactionModel transaction) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReceiptImageViewerScreen(
          path: transaction.receiptImagePath,
        ),
      ),
    );
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
          IconButton(
            key: CalendarAppKeys.openButton,
            tooltip: '取引カレンダー',
            icon: const Icon(Icons.calendar_month),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TransactionCalendarScreen()),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final result = _queryResult();
          return Column(
            children: [
              // ── フィルタバー（上部固定） ──
              TransactionFilterBar(
                initialFilter: _controller.filter,
                onChanged: (filter) => _controller.updateFilter(filter),
                availableCategories: _availableCategories(),
                availableTags: _tags,
              ),
              // ── 絞込結果サマリー ──
              if (!_controller.isLoading && _controller.error == null)
                TransactionQuerySummaryBar(
                  count: result.count,
                  totalIncome: result.totalIncome,
                  totalExpense: result.totalExpense,
                  isEmpty: result.isEmpty,
                  onReset: _controller.filter.isDefault
                      ? null
                      : () => _controller.updateFilter(_defaultFilter()),
                ),
              // ── 取引一覧（絞込結果。残りの領域を占有） ──
              Expanded(
                child: TransactionListWidget(
                  transactions: result.transactions,
                  isLoading: _controller.isLoading,
                  errorMessage: _controller.error,
                  onRetry: () => _controller.refetch(),
                  onTransactionTap: _assignTags,
                  onReceiptTap: _openReceipt,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
