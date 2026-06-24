import 'package:flutter/material.dart';

import 'package:kozuchi/features/transaction_filter/domain/models/transaction_filter.dart';
import 'package:kozuchi/features/transaction_filter/presentation/widgets/transaction_filter_bar.dart';
import 'package:kozuchi/features/transaction_history/data/transaction_service.dart';
import 'package:kozuchi/features/transaction_history/presentation/state/transaction_controller.dart';
import 'package:kozuchi/features/transaction_history/presentation/widgets/transaction_list_widget.dart';

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

  const TransactionHistoryPage({super.key, this.controller});

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
      _controller = TransactionController(
        service: TransactionService(),
        initialFilter: _defaultFilter(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('取引履歴')),
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
