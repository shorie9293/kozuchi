import 'package:flutter/material.dart';

import 'package:kozuchi/features/installment/data/installment_repository.dart';
import 'package:kozuchi/features/installment/domain/installment_service.dart';
import 'package:kozuchi/features/installment/domain/models/installment_plan.dart';
import 'package:kozuchi/features/installment/domain/models/subscription.dart';
import 'package:kozuchi/features/installment/domain/upcoming_billing_summary.dart';
import 'package:kozuchi/features/installment/presentation/installment_app_keys.dart';

/// 次回請求スケジュール画面。
///
/// 分割払い・サブスクの今後の支払い予定を日別に集約して一覧する。
/// [repository] で永続化先を差し替え可能（試練では SharedPreferences のモックを使用）。
/// [now] を注入すると「現在日」を固定して決定論的に集計できる。
class UpcomingBillingScreen extends StatefulWidget {
  final InstallmentRepository repository;

  /// 集計基準日（省略時は現在日時）
  final DateTime? now;

  /// 初期選択される集計期間（日数）
  final int initialWithinDays;

  const UpcomingBillingScreen({
    super.key,
    this.repository = const InstallmentRepository(),
    this.now,
    this.initialWithinDays = 30,
  });

  @override
  State<UpcomingBillingScreen> createState() => _UpcomingBillingScreenState();
}

class _UpcomingBillingScreenState extends State<UpcomingBillingScreen> {
  static const _windowChoices = <int>[7, 30, 90];

  List<InstallmentPlan> _plans = const [];
  List<Subscription> _subscriptions = const [];
  late int _withinDays;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _withinDays = widget.initialWithinDays;
    _load();
  }

  Future<void> _load() async {
    final results =
        await Future.wait([widget.repository.loadPlans(), widget.repository.loadSubscriptions()]);
    if (!mounted) return;
    setState(() {
      _plans = results[0] as List<InstallmentPlan>;
      _subscriptions = results[1] as List<Subscription>;
      _isLoading = false;
    });
  }

  void _setWithinDays(int days) {
    setState(() => _withinDays = days);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final summary = UpcomingBillingSummaryService.build(
      plans: _plans,
      subscriptions: _subscriptions,
      withinDays: _withinDays,
      from: widget.now,
    );

    return Scaffold(
      key: InstallmentAppKeys.upcomingScreen,
      appBar: AppBar(title: const Text('支払い予定')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSummaryCard(colorScheme, summary),
                Expanded(
                  child: summary.isEmpty
                      ? const Center(
                          child: Text(
                            '支払い予定はありません',
                            key: InstallmentAppKeys.upcomingEmpty,
                          ),
                        )
                      : ListView.builder(
                          itemCount: summary.groups.length,
                          itemBuilder: (context, index) =>
                              _buildGroup(colorScheme, summary.groups[index]),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryCard(ColorScheme colorScheme, UpcomingBillingSummary summary) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (final days in _windowChoices) ...[
                  ChoiceChip(
                    key: InstallmentAppKeys.upcomingWindowChip(days),
                    label: Text('$days日'),
                    selected: _withinDays == days,
                    onSelected: (_) => _setWithinDays(days),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '合計',
              style: TextStyle(fontSize: 13, color: colorScheme.outline),
            ),
            const SizedBox(height: 4),
            Text(
              key: InstallmentAppKeys.upcomingTotal,
              _formatYen(summary.totalAmount),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              key: InstallmentAppKeys.upcomingCount,
              '件数 ${summary.count}件',
              style: TextStyle(fontSize: 13, color: colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroup(ColorScheme colorScheme, UpcomingBillingGroup group) {
    final yyyymmdd =
        '${group.date.year.toString().padLeft(4, '0')}'
        '${group.date.month.toString().padLeft(2, '0')}'
        '${group.date.day.toString().padLeft(2, '0')}';
    return Column(
      key: InstallmentAppKeys.upcomingDateGroup(yyyymmdd),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Text(
                '${group.date.month}月${group.date.day}日',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                _formatYen(group.totalAmount),
                style: TextStyle(fontSize: 13, color: colorScheme.outline),
              ),
            ],
          ),
        ),
        for (final billing in group.billings) _buildBillingTile(colorScheme, billing),
      ],
    );
  }

  Widget _buildBillingTile(ColorScheme colorScheme, UpcomingBilling billing) {
    final icon = billing.isSubscription ? '🔄' : '🧾';
    return Semantics(
      label: '支払い予定 ${billing.label}',
      child: ListTile(
        key: InstallmentAppKeys.upcomingBillingTile(billing.id),
        leading: Text(icon, style: const TextStyle(fontSize: 20)),
        title: Text(
          billing.label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          billing.category,
          style: TextStyle(fontSize: 12, color: colorScheme.outline),
        ),
        trailing: Text(
          _formatYen(billing.amount),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

/// 円表記（3桁区切り、¥ 接頭）。
String _formatYen(int amount) {
  final negative = amount < 0;
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '${negative ? '-' : ''}¥$buffer';
}
