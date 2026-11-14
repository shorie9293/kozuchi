import 'package:flutter/material.dart';

import 'package:takamagahara_ui/takamagahara_ui.dart';
import 'package:kozuchi/core/infrastructure/cloud_sync_service.dart';
import 'package:kozuchi/core/haptics.dart';
import 'package:kozuchi/core/logging/app_logger.dart';
import 'package:kozuchi/core/infrastructure/supabase_provider.dart';
import 'package:kozuchi/domain/services/expense_entry_mapper.dart';
import 'package:kozuchi/domain/services/expense_repository.dart';
import 'package:kozuchi/domain/services/supabase_expense_repository.dart';
import 'package:kozuchi/features/calendar/presentation/calendar_app_keys.dart';
import 'package:kozuchi/features/calendar/presentation/transaction_calendar_screen.dart';
import 'package:kozuchi/features/budget/domain/budget_period.dart';
import 'package:kozuchi/features/csv_import/data/local_transaction_repository.dart';
import 'package:kozuchi/features/tags/domain/models/expense_tag.dart';
import 'package:kozuchi/features/transaction_filter/domain/models/transaction_filter.dart';
import 'package:kozuchi/features/transaction_filter/domain/models/transaction_query_result.dart';
import 'package:kozuchi/features/transaction_filter/domain/services/transaction_query_service.dart';
import 'package:kozuchi/features/transaction_filter/presentation/widgets/transaction_filter_bar.dart';
import 'package:kozuchi/features/transaction_filter/presentation/widgets/transaction_query_summary_bar.dart';
import 'package:kozuchi/features/receipt_viewer/presentation/screens/receipt_image_viewer_screen.dart';
import 'package:kozuchi/features/transaction_edit/presentation/widgets/transaction_edit_dialog.dart';
import 'package:kozuchi/features/transaction_history/domain/bulk_delete_service.dart';
import 'package:kozuchi/features/transaction_history/domain/bulk_selection.dart';
import 'package:kozuchi/features/transaction_history/presentation/state/transaction_controller.dart';
import 'package:kozuchi/features/transaction_history/presentation/widgets/transaction_list_item.dart';
import 'package:kozuchi/features/transaction_history/presentation/widgets/transaction_list_widget.dart';
import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/tags/data/tag_repository.dart';
import 'package:kozuchi/features/tags/domain/models/tagged_transaction.dart';
import 'package:kozuchi/features/tags/presentation/screens/tag_management_screen.dart';
import 'package:kozuchi/features/tags/presentation/screens/tag_summary_screen.dart';
import 'package:kozuchi/features/tags/presentation/tag_app_keys.dart';
import 'package:kozuchi/features/tags/presentation/widgets/tag_assignment_dialog.dart';
import 'package:kozuchi/features/undo/domain/undo_buffer.dart';
import 'package:kozuchi/features/undo/presentation/undo_snack_bar.dart';

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

  /// 締め日の読み込み関数（null の場合は暦月＝従来挙動）。
  ///
  /// 例: `const SharedPreferencesClosingDayRepository().load`
  final Future<int> Function()? closingDayLoader;

  /// 現在時刻の取得関数（試練で固定日付を注入可能。null の場合は実時計）。
  final DateTime Function()? clock;

  const TransactionHistoryPage({
    super.key,
    this.controller,
    this.localRepository,
    this.tagRepository = const TagRepository(),
    this.closingDayLoader,
    this.clock,
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

  /// 家計の締め日（1＝暦月。loader 未注入時は常に 1）。
  int _closingDay = BudgetPeriodService.defaultClosingDay;

  /// 現在時刻（clock 注入時はその値、未注入時は実時計）。
  DateTime _now() => (widget.clock ?? DateTime.now)();

  /// 削除した取引のUndoバッファ（直前の1件のみ・一度だけ復元可能）。
  final UndoBuffer<TransactionModel> _undoBuffer =
      UndoBuffer<TransactionModel>();

  /// Supabase 支出明細の保存先（孤児紐付けの判定に全期間キーを集めるため保持）。
  ExpenseRepository? _expenseRepository;

  /// クラウド読込の警告（読み飛ばし・照合不能）を既に表示したか。
  ///
  /// 再読込のたびに同じ SnackBar を積み重ねないための一度きりフラグ。
  bool _cloudLoadNoticeShown = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
    } else {
      // 案B: 取引履歴は Supabase `expense_entries`（支出明細）を正とする。
      // 旧 localhost:8080 API（TransactionService）には依存しない。
      final expenseRepository = SupabaseExpenseRepository(
        cloudStore: CloudSyncService(client: SupabaseProvider.client),
        userIdProvider: () => SupabaseProvider.currentUserId,
      );
      _expenseRepository = expenseRepository;
      _controller = TransactionController(
        expenseRepository: expenseRepository,
        initialFilter: _defaultFilter(),
        localRepository: widget.localRepository,
        // 削除時のタグ紐付け掃除・Undo 復元のためタグリポジトリを渡す。
        tagRepository: widget.tagRepository,
      );
      _ownsController = true;
    }
    _controller.fetchTransactions();
    _loadTags();
    _controller.addListener(_onControllerChanged);
    _loadClosingDay();
  }

  /// 締め日を読み込み、読み込めた場合のみ既定フィルタを組み直す。
  Future<void> _loadClosingDay() async {
    final loader = widget.closingDayLoader;
    if (loader == null) return;

    int loaded;
    try {
      loaded = await loader();
    } catch (_) {
      // 読み込み失敗時は既定（暦月）に倒し、画面は壊さない。
      loaded = BudgetPeriodService.defaultClosingDay;
    }
    if (!mounted) return;
    setState(() {
      _closingDay = BudgetPeriodService.normalize(loaded);
    });
    _controller.updateFilter(_defaultFilter());
  }

  @override
  void dispose() {
    _undoBuffer.clear();
    _controller.removeListener(_onControllerChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  /// コントローラ更新（再取得・フィルタ変更）時にタグ紐付けを再読込する。
  void _onControllerChanged() {
    _loadTags();
    _notifyCloudLoadIssues();
  }

  /// 直近の読込で読み飛ばし・照合不能があれば一度だけ警告する（非ブロッキング）。
  ///
  /// 明細が静かに減ると家計の集計が狂うため、握り潰さずに可視化する。
  /// 再読込で同じ通知を積み重ねないよう [_cloudLoadNoticeShown] で一度きりにする。
  void _notifyCloudLoadIssues() {
    if (_cloudLoadNoticeShown) return;
    final repository = _expenseRepository;
    if (repository is! SupabaseExpenseRepository) return;

    if (!repository.lastCanVerify) {
      _cloudLoadNoticeShown = true;
      appLog.warn('expense_entries: クラウド明細を照合できませんでした（応答がリストでない）');
      _showCloudLoadNotice('⚠️ クラウド明細を照合できませんでした');
      return;
    }
    if (repository.lastSkippedCount > 0) {
      final skipped = repository.lastSkippedCount;
      _cloudLoadNoticeShown = true;
      appLog.warn('expense_entries: クラウドの明細 $skipped件を型不整合のため読み飛ばしました');
      _showCloudLoadNotice('⚠️ クラウドの明細 $skipped件を型不整合のため読み飛ばしました');
    }
  }

  /// クラウド読込の警告を SnackBar で出す（画面操作はブロックしない）。
  void _showCloudLoadNotice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
    );
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
  /// - 開始日: 現在期間の初日（締め日 1 なら従来どおり月初）
  /// - 終了日: 本日
  TransactionFilter _defaultFilter() {
    final now = _now();
    final period = BudgetPeriodService.periodFor(
      now,
      closingDay: _closingDay,
    );
    return TransactionFilter(
      type: TransactionFilterType.all,
      startDate: period.start,
      endDate: DateTime(now.year, now.month, now.day),
    );
  }

  /// 全期間の取引キーを集める（孤児タグ紐付けの判定用）。
  ///
  /// Supabase 支出明細（全期間）とローカル取引を取引キーへ変換する。
  /// 取得に失敗した場合は例外を投げる（呼び出し側の画面が握る）。
  Future<List<String>> _loadAllTransactionKeys() async {
    final keys = <String>{};
    final expenseRepo = _expenseRepository;
    if (expenseRepo != null) {
      final entries = await expenseRepo.getEntries(
        start: DateTime(2000),
        end: DateTime(2100),
      );
      final transactions = ExpenseEntryMapper.toTransactionModels(entries);
      for (final transaction in transactions) {
        keys.add(TaggedTransaction.keyOfTransaction(transaction));
      }
    }
    final localRepo = widget.localRepository;
    if (localRepo != null) {
      for (final transaction in await localRepo.loadAll()) {
        keys.add(TaggedTransaction.keyOfTransaction(transaction));
      }
    }
    return List.unmodifiable(keys.toList());
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

  /// 取引を編集する（ダイアログ → コントローラ経由で保存）。
  Future<void> _editTransaction(TransactionModel transaction) async {
    final messenger = ScaffoldMessenger.of(context);
    final edited = await TransactionEditDialog.show(
      context,
      transaction: transaction,
    );
    if (edited == null || !mounted) return;
    final ok = await _controller.updateTransaction(edited);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(ok ? '取引を更新しました' : 'この取引は編集できません')),
    );
  }

  /// 取引を削除する（確認ダイアログ → コントローラ経由で削除 → Undo スナックバー）。
  ///
  /// 削除は即時実行し、直後に「元に戻す」付きスナックバーを表示する。
  /// 元に戻すと、削除直前の取引コピーを既存の保存APIで再登録する
  /// （同一IDが既に存在する場合は何もしない）。
  Future<void> _deleteTransaction(TransactionModel transaction) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showTransactionDeleteConfirmDialog(
      context,
      transaction: transaction,
    );
    if (!confirmed || !mounted) return;
    // 削除確定の触覚フィードバック（await 禁止）
    hapticTap();
    // 削除対象のコピーを保持（モデルは不変なのでコピーで十分）。
    final snapshot = transaction.copyWith();
    final ok = await _controller.deleteTransaction(transaction);
    if (!mounted) return;
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('この取引は削除できません')),
      );
      return;
    }
    _undoBuffer.push(snapshot);
    showUndoSnackBar(
      context,
      message: '取引を削除しました',
      onUndo: _undoDelete,
    );
  }

  /// 直前の削除を取り消す（バッファは一度だけ取り出せる）。
  void _undoDelete() {
    final snapshot = _undoBuffer.take();
    if (snapshot == null) return;
    _restoreTransaction(snapshot);
  }

  /// 削除した取引を復元する（失敗しても画面は壊さない）。
  Future<void> _restoreTransaction(TransactionModel transaction) async {
    await _controller.restoreTransaction(transaction);
  }

  // ── 一括選択モード ──────────────────────────────────────

  /// 一括選択の状態（空＝通常モード）。
  BulkSelection _selection = const BulkSelection.empty();

  /// 一括選択モード中か（1件以上選択されている間）。
  bool get _isSelecting => _selection.isSelecting;

  /// 一括削除の実行中か（二重実行の防止）。
  bool _isBulkDeleting = false;

  /// 行の長押し／選択モード中のタップで選択をトグルする。
  ///
  /// 長押しで呼ばれた場合はその取引が選択され、選択モードが開始する。
  void _toggleSelection(TransactionModel transaction) {
    final id = transaction.id;
    if (id == null || id.isEmpty) return;
    hapticTap();
    setState(() {
      _selection = _selection.toggle(id);
    });
  }

  /// 表示中の取引をすべて選択に加える（全選択）。
  void _selectAllVisible(List<TransactionModel> visible) {
    final ids = <String>[];
    for (final transaction in visible) {
      final id = transaction.id;
      if (id != null && id.isNotEmpty) ids.add(id);
    }
    if (ids.isEmpty) return;
    setState(() {
      _selection = _selection.selectAll(ids);
    });
  }

  /// 選択をすべて解除して通常モードへ戻る。
  void _clearSelection() {
    if (!_isSelecting) return;
    setState(() {
      _selection = const BulkSelection.empty();
    });
  }

  /// 一括削除の確認ダイアログを出す。確定で true。
  Future<bool> _confirmBulkDelete(int count) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('一括削除'),
        content: Text('選択した $count件を削除します。取り消せます。'),
        actions: [
          TextButton(
            key: HistorySelectionKeys.cancelDelete,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            key: HistorySelectionKeys.confirmDelete,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// 選択中の取引を一括削除する。
  ///
  /// [visible] には**画面に表示中の取引のみ**を渡す。計画（
  /// [buildBulkDeletePlan]）が visible と照合するため、絞込中でも
  /// 絞込外の取引を巻き込まない。成功分は Undo で元順序のまま復元する。
  Future<void> _deleteSelected(List<TransactionModel> visible) async {
    if (_isBulkDeleting || !_isSelecting) return;
    final messenger = ScaffoldMessenger.of(context);
    final plan = buildBulkDeletePlan(visible: visible, selection: _selection);
    if (plan.toDelete.isEmpty) {
      setState(() {
        _selection = const BulkSelection.empty();
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('削除できる取引がありません')),
      );
      return;
    }

    final confirmed = await _confirmBulkDelete(plan.toDelete.length);
    if (!confirmed || !mounted) return;
    hapticTap();

    setState(() {
      _isBulkDeleting = true;
    });
    final outcome = await BulkDeleteService(
      deleteOne: _controller.deleteTransaction,
    ).run(plan.toDelete);
    if (!mounted) return;
    setState(() {
      _isBulkDeleting = false;
      _selection = const BulkSelection.empty();
    });

    if (outcome.deleted == 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('この取引は削除できません')),
      );
      return;
    }

    final message = outcome.isComplete
        ? '${outcome.deleted}件の取引を削除しました'
        : '${outcome.deleted}件を削除しました（${outcome.failed}件は失敗）';
    final deletedItems = outcome.deletedItems;
    showUndoSnackBar(
      context,
      message: message,
      onUndo: () => _restoreDeletedItems(deletedItems),
    );
  }

  /// 一括削除した取引を元順序のまま逐次復元する（失敗は握る）。
  Future<void> _restoreDeletedItems(List<TransactionModel> items) async {
    for (final item in items) {
      try {
        await _controller.restoreTransaction(item);
      } catch (_) {
        // 1件の復元失敗で残りの復元を止めない（画面は壊さない）
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // AppBar（選択件数・全選択）でも表示集合を参照するため先に求める。
    final result = _queryResult();
    return Scaffold(
      appBar: AppBar(
        title:
            _isSelecting ? Text('${_selection.count}件選択') : const Text('取引履歴'),
        actions: _isSelecting
            ? [
                // ── 選択モード中は「全選択」「閉じる」に差し替える ──
                SemanticHelper.interactive(
                  testId: 'history_btn_bulk_select_all',
                  label: '全選択',
                  child: IconButton(
                    key: HistorySelectionKeys.selectAll,
                    tooltip: '全選択',
                    icon: const Icon(Icons.select_all),
                    onPressed: () => _selectAllVisible(result.transactions),
                  ),
                ),
                SemanticHelper.interactive(
                  testId: 'history_btn_bulk_close',
                  label: '選択を閉じる',
                  child: IconButton(
                    key: HistorySelectionKeys.close,
                    tooltip: '閉じる',
                    icon: const Icon(Icons.close),
                    onPressed: _clearSelection,
                  ),
                ),
              ]
            : [
                SemanticHelper.interactive(
                  testId: 'history_btn_tag_manage',
                  label: 'タグ管理',
                  child: IconButton(
                    key: TagAppKeys.historyTagManageButton,
                    tooltip: 'タグ管理',
                    icon: const Icon(Icons.sell_outlined),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TagManagementScreen(
                          repository: widget.tagRepository,
                          orphanKeyLoader: _loadAllTransactionKeys,
                        ),
                      ),
                    ),
                  ),
                ),
                SemanticHelper.interactive(
                  testId: 'history_btn_tag_summary',
                  label: 'タグ別集計',
                  child: IconButton(
                    key: TagAppKeys.historyTagSummaryButton,
                    tooltip: 'タグ別集計',
                    icon: const Icon(Icons.label_outline),
                    onPressed: () => _openTagSummary(context),
                  ),
                ),
                SemanticHelper.interactive(
                  testId: 'history_btn_open_calendar',
                  label: '取引カレンダー',
                  child: IconButton(
                    key: CalendarAppKeys.openButton,
                    tooltip: '取引カレンダー',
                    icon: const Icon(Icons.calendar_month),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const TransactionCalendarScreen()),
                    ),
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
                  // 選択モード中のタップは「選択トグル」に差し替える。
                  onTransactionTap:
                      _isSelecting ? _toggleSelection : _assignTags,
                  onLongPress: _toggleSelection,
                  selection: _selection,
                  selectionMode: _isSelecting,
                  onReceiptTap: _openReceipt,
                  onEditTap: _editTransaction,
                  onDeleteTap: _deleteTransaction,
                ),
              ),
              // ── 一括選択バー（選択中のみ） ──
              if (_isSelecting) _buildSelectionBar(result.transactions),
            ],
          );
        },
      ),
    );
  }

  /// 一括選択モードの下部バー（削除・解除）。
  ///
  /// [visible] は画面に表示中の取引のみ。削除はこの集合と選択を照合するため、
  /// 絞込外の取引を巻き込まない。
  Widget _buildSelectionBar(List<TransactionModel> visible) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      color: colorScheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: SemanticHelper.interactive(
                  testId: 'history_btn_bulk_delete',
                  label: '選択した取引を削除',
                  child: FilledButton.icon(
                    key: HistorySelectionKeys.deleteButton,
                    onPressed:
                        _isBulkDeleting ? null : () => _deleteSelected(visible),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('削除'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SemanticHelper.interactive(
                testId: 'history_btn_bulk_clear',
                label: '選択を解除',
                child: TextButton(
                  key: HistorySelectionKeys.clearButton,
                  onPressed: _clearSelection,
                  child: const Text('解除'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
