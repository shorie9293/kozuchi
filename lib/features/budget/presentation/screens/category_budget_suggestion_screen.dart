import 'package:flutter/material.dart';
import 'package:kozuchi/core/infrastructure/cloud_sync_service.dart';
import 'package:kozuchi/core/infrastructure/supabase_provider.dart';
import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/domain/services/supabase_expense_repository.dart';
import 'package:kozuchi/features/budget/data/category_budget_repository.dart';
import 'package:kozuchi/features/budget/domain/category_budget_suggestion.dart';
import 'package:kozuchi/features/budget/domain/category_budget_suggestion_service.dart';
import 'package:kozuchi/features/budget/presentation/category_budget_suggestion_app_keys.dart';

/// カテゴリ別予算の推奨額を表示・適用する画面
///
/// 過去Nヶ月の支出実績から [CategoryBudgetSuggestionService] が算出した
/// 推奨額をカテゴリごとに提示し、「この額を設定」で予算として保存できる。
class CategoryBudgetSuggestionScreen extends StatefulWidget {
  /// カテゴリ別予算の永続化リポジトリ
  final CategoryBudgetRepository repository;

  /// 支出エントリ取得ローダ（nullなら既定実装＝Supabaseから直近Nヶ月を取得）
  final Future<List<ExpenseEntry>> Function()? entriesLoader;

  /// 現在日時（試練で固定日時を注入できるように）
  final DateTime Function()? clock;

  /// 集計対象の月数
  final int monthsToConsider;

  /// 推奨額算出サービス
  final CategoryBudgetSuggestionService service;

  const CategoryBudgetSuggestionScreen({
    super.key,
    this.repository = const CategoryBudgetRepository(),
    this.entriesLoader,
    this.clock,
    this.monthsToConsider =
        CategoryBudgetSuggestionService.defaultMonthsToConsider,
    this.service = const CategoryBudgetSuggestionService(),
  });

  @override
  State<CategoryBudgetSuggestionScreen> createState() =>
      _CategoryBudgetSuggestionScreenState();
}

class _CategoryBudgetSuggestionScreenState
    extends State<CategoryBudgetSuggestionScreen> {
  late DateTime _now;
  List<CategoryBudgetSuggestion> _suggestions = const [];
  bool _isLoading = true;
  bool _hasError = false;
  final Set<String> _applied = <String>{};

  @override
  void initState() {
    super.initState();
    _now = (widget.clock ?? DateTime.now)();
    _reload();
  }

  /// 推奨額を再算出する
  Future<void> _reload() async {
    try {
      final loader = widget.entriesLoader ?? _defaultEntriesLoader;
      final entries = await loader();
      final suggestions = widget.service.suggest(
        entries: entries,
        now: _now,
        monthsToConsider: widget.monthsToConsider,
      );
      if (!mounted) return;
      setState(() {
        _suggestions = suggestions;
        _isLoading = false;
        _hasError = false;
      });
    } catch (error) {
      // 例外は握りつぶさず、エラー表示してクラッシュしない
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  /// 既定の支出ローダ（Supabaseから直近Nヶ月の支出一覧を取得）
  Future<List<ExpenseEntry>> _defaultEntriesLoader() async {
    final start = DateTime(
      _now.year,
      _now.month - (widget.monthsToConsider - 1),
      1,
    );
    final end = DateTime(_now.year, _now.month + 1, 0, 23, 59, 59);
    return SupabaseExpenseRepository(
      cloudStore: CloudSyncService(client: SupabaseProvider.client),
      userIdProvider: () => SupabaseProvider.currentUserId,
    ).getEntries(start: start, end: end);
  }

  /// 「この額を設定」タップ処理：予算を保存し適用済みにする
  Future<void> _apply(CategoryBudgetSuggestion suggestion) async {
    await widget.repository.saveBudget(
      suggestion.yearMonth,
      suggestion.category,
      suggestion.recommendedBudget,
    );
    if (!mounted) return;
    setState(() => _applied.add(suggestion.category));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '「${suggestion.category}」の予算を '
          '¥${suggestion.recommendedBudget} に設定しました',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: CategoryBudgetSuggestionAppKeys.suggestionScreen,
      appBar: AppBar(
        title: const Text('カテゴリ別予算の推奨額'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                key: CategoryBudgetSuggestionAppKeys.loading,
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '過去 ${widget.monthsToConsider} ヶ月の支出実績から、'
                  'カテゴリごとの予算額を提案します。',
                ),
                const SizedBox(height: 16),
                if (_hasError)
                  const Text('支出データの読み込みに失敗しました')
                else if (_suggestions.isEmpty)
                  const Text(
                    '推奨できるカテゴリがありません（支出実績がありません）',
                    key: CategoryBudgetSuggestionAppKeys.emptyState,
                  )
                else
                  for (final suggestion in _suggestions)
                    _SuggestionCard(
                      suggestion: suggestion,
                      applied: _applied.contains(suggestion.category),
                      onApply: () => _apply(suggestion),
                    ),
              ],
            ),
    );
  }
}

/// 推奨額1件分のカード
class _SuggestionCard extends StatelessWidget {
  final CategoryBudgetSuggestion suggestion;
  final bool applied;
  final Future<void> Function() onApply;

  const _SuggestionCard({
    required this.suggestion,
    required this.applied,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final category = suggestion.category;
    return Card(
      key: CategoryBudgetSuggestionAppKeys.row(category),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          category,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '推奨 ¥${suggestion.recommendedBudget}',
              key: CategoryBudgetSuggestionAppKeys.recommended(category),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '平均 ¥${suggestion.averageMonthlySpent}・'
              '最大 ¥${suggestion.maxMonthlySpent}・'
              '${suggestion.monthsWithSpend}/${suggestion.monthsConsidered}ヶ月',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        trailing: applied
            ? Icon(
                Icons.check_circle,
                key: CategoryBudgetSuggestionAppKeys.appliedMark(category),
                color: Theme.of(context).colorScheme.primary,
              )
            : TextButton(
                key: CategoryBudgetSuggestionAppKeys.applyButton(category),
                onPressed: onApply,
                child: const Text('この額を設定'),
              ),
      ),
    );
  }
}