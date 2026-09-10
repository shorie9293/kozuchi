import 'package:flutter/material.dart';

import 'package:kozuchi/core/infrastructure/cloud_sync_service.dart';
import 'package:kozuchi/core/infrastructure/supabase_provider.dart';
import 'package:kozuchi/domain/services/supabase_expense_repository.dart';
import 'package:kozuchi/features/asset_trend/domain/asset_trend_service.dart';
import 'package:kozuchi/features/asset_trend/domain/monthly_asset_point.dart';
import 'package:kozuchi/features/asset_trend/presentation/widgets/asset_trend_chart.dart';
import 'package:kozuchi/features/csv_import/data/local_transaction_repository.dart';
import 'package:kozuchi/features/transaction_history/presentation/state/transaction_controller.dart';

/// 資産推移画面。
///
/// 収入 − 支出の累積残高と月次純資産の推移を折れ線グラフで可視化する。
/// データソースは [TransactionController] と同一（Supabase 支出明細 +
/// ローカル取引）。テスト時は [controller] を注入可能。
class AssetTrendScreen extends StatefulWidget {
  /// テスト用に注入可能なコントローラ。null なら実データソースを生成する。
  final TransactionController? controller;

  /// ローカル取引（CSVインポート・定期取引）の保存先。
  final LocalTransactionRepository? localRepository;

  /// 集計月数（デフォルト: 12ヶ月）
  final int months;

  /// 集計の基準日（テスト用）。null なら [DateTime.now]。
  final DateTime? now;

  const AssetTrendScreen({
    super.key,
    this.controller,
    this.localRepository,
    this.months = AssetTrendService.defaultMonths,
    this.now,
  });

  @override
  State<AssetTrendScreen> createState() => _AssetTrendScreenState();
}

class _AssetTrendScreenState extends State<AssetTrendScreen> {
  static const AssetTrendService _service = AssetTrendService();

  late final TransactionController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
    } else {
      // 取引履歴画面と同一のデータソース構成（案B・一本化）。
      _controller = TransactionController(
        expenseRepository: SupabaseExpenseRepository(
          cloudStore: CloudSyncService(client: SupabaseProvider.client),
          userIdProvider: () => SupabaseProvider.currentUserId,
        ),
        localRepository: widget.localRepository,
      );
      _ownsController = true;
    }
    if (_ownsController) {
      // 取得失敗はコントローラ内で error に丸められる（画面が落ちない）。
      _controller.fetchTransactions();
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('asset_trend_screen'),
      appBar: AppBar(title: const Text('資産推移')),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          final error = _controller.error;
          if (error != null) {
            return _buildError(error);
          }
          final points = _service.buildMonthlyTrend(
            _controller.transactions,
            now: widget.now,
            months: widget.months,
          );
          if (points.isEmpty) {
            return const Center(child: Text('資産推移データがありません'));
          }
          return _buildContent(points);
        },
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => _controller.refetch(),
              child: const Text('再試行'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(List<MonthlyAssetPoint> points) {
    final summary = _service.summarize(points);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSummaryCard(summary, points.length),
        const SizedBox(height: 16),
        AssetTrendChart(points: points),
        const SizedBox(height: 16),
        _buildMonthlyList(points),
      ],
    );
  }

  Widget _buildSummaryCard(AssetTrendSummary summary, int months) {
    final theme = Theme.of(context);
    return Container(
      key: const Key('asset_trend_summary'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '現在の残高',
            style: theme.textTheme.labelMedium,
          ),
          Text(
            '¥${_formatYen(summary.latestBalance)}',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '直近$monthsヶ月: 収入 ¥${_formatYen(summary.totalIncome)} / '
            '支出 ¥${_formatYen(summary.totalExpense)}',
            style: theme.textTheme.bodySmall,
          ),
          Text(
            '月平均の純増減: ¥${_formatYen(summary.averageMonthlyNet.round())}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyList(List<MonthlyAssetPoint> points) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('月別の推移', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        // 新しい月を上に表示する
        for (final p in points.reversed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  child: Text(p.label, style: theme.textTheme.bodySmall),
                ),
                Expanded(
                  child: Text(
                    '¥${_formatYen(p.balance)}',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  '${p.netChange >= 0 ? '+' : '-'}¥${_formatYen(p.netChange.abs())}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: p.netChange >= 0
                        ? Colors.green
                        : theme.colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static String _formatYen(int value) {
    final s = value.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write(',');
      buffer.write(s[i]);
    }
    return value < 0 ? '-$buffer' : buffer.toString();
  }
}
