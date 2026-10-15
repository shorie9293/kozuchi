import 'package:flutter/material.dart';
import 'package:kozuchi/core/infrastructure/cloud_sync_service.dart';
import 'package:kozuchi/core/infrastructure/supabase_provider.dart';
import 'package:kozuchi/domain/services/expense_repository.dart';
import 'package:kozuchi/domain/services/supabase_expense_repository.dart';
import 'package:kozuchi/features/budget/domain/expense_anomaly.dart';
import 'package:kozuchi/features/budget/domain/expense_anomaly_service.dart';
import 'package:kozuchi/features/budget/presentation/expense_anomaly_app_keys.dart';

/// 支出の異常検知画面
///
/// 過去 [lookbackDays] 日の支出履歴から、いつもより高い支出を検知して表示する。
/// [repository] が null の場合は本番実装（Supabase）を使用する。
class ExpenseAnomalyScreen extends StatefulWidget {
  /// 支出履歴の取得先（null なら本番 SupabaseExpenseRepository を生成）
  final ExpenseRepository? repository;

  /// 現在日時（試練で固定日時を注入できるように）
  final DateTime Function()? now;

  /// 遡る日数（既定 180 日）
  final int lookbackDays;

  const ExpenseAnomalyScreen({
    super.key,
    this.repository,
    this.now,
    this.lookbackDays = 180,
  });

  @override
  State<ExpenseAnomalyScreen> createState() => _ExpenseAnomalyScreenState();
}

class _ExpenseAnomalyScreenState extends State<ExpenseAnomalyScreen> {
  bool _isLoading = true;
  List<ExpenseAnomaly> _anomalies = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 履歴を読み込み異常を検知する（失敗時は空扱いで落ちない）
  Future<void> _load() async {
    try {
      final current = widget.now?.call() ?? DateTime.now();
      final start = current.subtract(Duration(days: widget.lookbackDays));
      final repository = widget.repository ??
          SupabaseExpenseRepository(
            cloudStore: CloudSyncService(client: SupabaseProvider.client),
            userIdProvider: () => SupabaseProvider.currentUserId,
          );
      final entries = await repository.getEntries(start: start, end: current);
      final anomalies = const ExpenseAnomalyService().detectAll(entries);
      if (!mounted) return;
      setState(() {
        _anomalies = anomalies;
        _isLoading = false;
      });
    } catch (_) {
      // 例外を握りつぶし、空状態で表示する
      if (!mounted) return;
      setState(() {
        _anomalies = const [];
        _isLoading = false;
      });
    }
  }

  /// 最大倍率の表示用テキスト（例: 「最大 いつもの 2.4倍」）
  String get _maxRatioLabel {
    if (_anomalies.isEmpty) return '';
    var max = _anomalies.first.ratio;
    for (final a in _anomalies.skip(1)) {
      if (a.ratio > max) max = a.ratio;
    }
    final rounded = (max * 10).roundToDouble() / 10;
    return '最大 いつもの ${rounded.toStringAsFixed(1)}倍';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      key: ExpenseAnomalyAppKeys.anomalyScreen,
      appBar: AppBar(
        title: const Text('支出の異常検知'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _anomalies.isEmpty
              ? _EmptyState(colorScheme: colorScheme)
              : ListView(
                  key: ExpenseAnomalyAppKeys.list,
                  padding: const EdgeInsets.all(16),
                  children: [
                    _SummaryCard(
                      count: _anomalies.length,
                      maxRatioLabel: _maxRatioLabel,
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(height: 16),
                    for (final anomaly in _anomalies)
                      _AnomalyRow(
                        key: ExpenseAnomalyAppKeys.row(anomaly.entry.id),
                        anomaly: anomaly,
                        colorScheme: colorScheme,
                      ),
                  ],
                ),
    );
  }
}

/// 空状態（異常なし・履歴なし）
class _EmptyState extends StatelessWidget {
  final ColorScheme colorScheme;

  const _EmptyState({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        key: ExpenseAnomalyAppKeys.empty,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🕊️', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            '普段どおりの支出です',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '直近の支出に大きな偏りは見られません',
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// 検知件数と最大倍率のサマリーカード
class _SummaryCard extends StatelessWidget {
  final int count;
  final String maxRatioLabel;
  final ColorScheme colorScheme;

  const _SummaryCard({
    required this.count,
    required this.maxRatioLabel,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ExpenseAnomalyAppKeys.summary,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '検知件数 $count件 ・ $maxRatioLabel',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface,
        ),
      ),
    );
  }
}

/// 異常1行分の表示
class _AnomalyRow extends StatelessWidget {
  final ExpenseAnomaly anomaly;
  final ColorScheme colorScheme;

  const _AnomalyRow({
    super.key,
    required this.anomaly,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final isHigh = anomaly.level == AnomalyLevel.high;
    final levelColor = isHigh ? colorScheme.error : Colors.amber.shade700;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    anomaly.category,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  anomaly.level.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: levelColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '¥${anomaly.amount}',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${anomaly.ratioLabel} ・ ${anomaly.message}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: levelColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _dateLabel(anomaly.entry.date),
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _dateLabel(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
