import 'package:flutter/foundation.dart';

import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/domain/services/expense_entry_mapper.dart';
import 'package:kozuchi/domain/services/expense_repository.dart';
import 'package:kozuchi/features/csv_import/data/local_transaction_repository.dart';
import 'package:kozuchi/features/transaction_filter/domain/models/transaction_filter.dart';
import 'package:kozuchi/features/transaction_history/data/transaction_service.dart';

/// 取引履歴画面のデータ取得と状態管理を行うコントローラ
///
/// React の `useTransactions` カスタムフックに相当する。
/// [ChangeNotifier] を継承し、フィルタ変更・データ取得・
/// loading/error/data 状態の一元管理を行う。
///
/// データソースは複数あり、統合表示される（案B・履歴一本化）:
/// - [expenseRepository]: Supabase `expense_entries`（支出明細）
/// - [localRepository]: ローカル取引（CSVインポート・定期取引）
/// - [service]: 旧 API 取引（localhost:8080）。非推奨・移行用
class TransactionController extends ChangeNotifier {
  final TransactionService? _service;

  /// Supabase 支出明細（`expense_entries`）の保存先。
  final ExpenseRepository? _expenseRepository;

  /// CSVインポート・定期取引などで生成されたローカル取引の保存先。
  /// null の場合はローカル取引を表示しない。
  final LocalTransactionRepository? _localRepository;

  List<TransactionModel> _transactions = [];
  bool _isLoading = false;
  String? _error;
  TransactionFilter _filter;
  bool _hasFetched = false;

  TransactionController({
    TransactionService? service,
    TransactionFilter? initialFilter,
    LocalTransactionRepository? localRepository,
    ExpenseRepository? expenseRepository,
  })  : _service = service,
        _localRepository = localRepository,
        _expenseRepository = expenseRepository,
        _filter = initialFilter ?? const TransactionFilter();

  // ── 公開ゲッター ──────────────────────────────────

  /// 取得済みの取引一覧（変更不可）
  List<TransactionModel> get transactions => List.unmodifiable(_transactions);

  /// データ取得中か
  bool get isLoading => _isLoading;

  /// エラーメッセージ（取得成功時は null）
  String? get error => _error;

  /// 現在のフィルタ状態
  TransactionFilter get filter => _filter;

  /// 取引データがあるか（ロード中・エラー時は false）
  bool get hasData =>
      !_isLoading && _error == null && _transactions.isNotEmpty;

  /// 取引が空か（ロード完了後、データゼロ。未fetch時は false）
  bool get isEmpty =>
      _hasFetched && !_isLoading && _error == null && _transactions.isEmpty;

  // ── フィルタ操作 ──────────────────────────────────

  /// フィルタ条件を更新し、自動的にデータを再取得する
  ///
  /// [filter] が現在のフィルタと等しい場合は何もしない。
  void updateFilter(TransactionFilter filter) {
    if (filter == _filter) return;
    _filter = filter;
    fetchTransactions();
  }

  // ── データ取得 ──────────────────────────────────

  /// 取引データを取得する
  ///
  /// Supabase 支出明細 + ローカル取引（+ 旧API取引）を統合し、
  /// 日時の降順に整列する。ロード中は [isLoading]=true、
  /// 取得成功で [transactions] 更新、失敗時は [error] にエラーメッセージ。
  Future<void> fetchTransactions() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final fetched = <TransactionModel>[];

      // 旧 API 取引（移行用。未指定なら無視）
      final apiService = _service;
      if (apiService != null) {
        fetched.addAll(await apiService.fetchTransactions(filter: _filter));
      }

      // Supabase 支出明細（expense_entries）を統合
      final expenseRepo = _expenseRepository;
      if (expenseRepo != null) {
        final expenseTxs = await _loadExpenseTransactions(expenseRepo);
        fetched.addAll(expenseTxs);
      }

      // ローカル取引（CSVインポート・定期取引）を統合
      final localRepo = _localRepository;
      if (localRepo != null) {
        fetched.addAll(await localRepo.loadAll());
      }

      fetched.sort((a, b) => b.datetime.compareTo(a.datetime));

      _transactions = fetched;
      _error = null;
      _hasFetched = true;
    } catch (e) {
      _transactions = [];
      _error = e.toString();
      _hasFetched = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 現在のフィルタ条件でデータを再取得する
  Future<void> refetch() => fetchTransactions();

  // ── 内部ヘルパー ─────────────────────────────────

  /// 支出明細を日付範囲・種別フィルタで取得し取引モデルへ変換する。
  Future<List<TransactionModel>> _loadExpenseTransactions(
    ExpenseRepository repo,
  ) async {
    // 収入フィルタ時は支出明細を表示しない
    if (_filter.type == TransactionFilterType.income) return const [];

    final startDay = _filter.startDate ?? DateTime(2000);
    final endDay = _filter.endDate ?? DateTime(2100);
    final entries = await repo.getEntries(start: startDay, end: endDay);
    return ExpenseEntryMapper.toTransactionModels(entries);
  }

  // ── 破棄 ──────────────────────────────────────

  @override
  void dispose() {
    _service?.dispose();
    super.dispose();
  }
}
