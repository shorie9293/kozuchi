import 'package:flutter/foundation.dart';

import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/transaction_filter/domain/models/transaction_filter.dart';
import 'package:kozuchi/features/transaction_history/data/transaction_service.dart';

/// 取引履歴画面のデータ取得と状態管理を行うコントローラ
///
/// React の `useTransactions` カスタムフックに相当する。
/// [ChangeNotifier] を継承し、フィルタ変更・データ取得・
/// loading/error/data 状態の一元管理を行う。
///
/// ## 使用例
/// ```dart
/// final controller = TransactionController(service: myService);
///
/// // フィルタ変更時（TransactionFilterBar の onChanged から）
/// controller.updateFilter(newFilter); // 自動的にデータ再取得
///
/// // UI で ListenableBuilder を使って状態を購読
/// ListenableBuilder(
///   listenable: controller,
///   builder: (context, _) {
///     if (controller.isLoading) return CircularProgressIndicator();
///     if (controller.error != null) return ErrorWidget(controller.error!);
///     return ListView(
///       children: controller.transactions
///           .map((t) => TransactionListItem(transaction: t))
///           .toList(),
///     );
///   },
/// );
///
/// // 再取得（フィルタ変更なしのリフレッシュ）
/// controller.refetch();
/// ```
class TransactionController extends ChangeNotifier {
  final TransactionService _service;

  List<TransactionModel> _transactions = [];
  bool _isLoading = false;
  String? _error;
  TransactionFilter _filter;
  bool _hasFetched = false;

  TransactionController({
    required TransactionService service,
    TransactionFilter? initialFilter,
  })  : _service = service,
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
  /// [filter] が現在のフィルタと等しい場合は何もしない
  /// （無駄な API コールを避ける）。
  void updateFilter(TransactionFilter filter) {
    if (filter == _filter) return;
    _filter = filter;
    fetchTransactions();
  }

  // ── データ取得 ──────────────────────────────────

  /// 取引データを API から取得する
  ///
  /// ロード中は [isLoading]=true、取得成功で [transactions] 更新、
  /// 失敗時は [error] にエラーメッセージが入る。
  /// いずれの場合も [notifyListeners] で UI に通知する。
  Future<void> fetchTransactions() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _transactions = await _service.fetchTransactions(filter: _filter);
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
  ///
  /// [fetchTransactions] のエイリアス。
  /// フィルタ変更を伴わない単純な再読込に使用する。
  Future<void> refetch() => fetchTransactions();

  // ── 破棄 ──────────────────────────────────────

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
