import 'package:flutter/material.dart';

import '../../domain/models/income_entry.dart';
import '../../domain/models/income_source_summary.dart';
import '../../domain/services/income_analysis_service.dart';
import '../widgets/income_analysis_keys.dart';

/// 収入源別の内訳分析画面。
///
/// [IncomeEntry] のリストを収入源ごとに集計し、
/// 金額・件数・構成比を一覧表示する。
///
/// - [entriesOverride]: 試練用のデータ注入（null なら [entries] を用いる）
/// - 試練は entriesOverride で固定データを注入するため実リポジトリ不要
class IncomeAnalysisScreen extends StatefulWidget {
  /// 分析対象の収入エントリ
  final List<IncomeEntry> entries;

  /// 試練用の上書きデータ（getter で毎回評価される）
  final List<IncomeEntry>? entriesOverride;

  const IncomeAnalysisScreen({
    super.key,
    required this.entries,
    this.entriesOverride,
  });

  @override
  State<IncomeAnalysisScreen> createState() => _IncomeAnalysisScreenState();
}

class _IncomeAnalysisScreenState extends State<IncomeAnalysisScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {});
  }

  // late final で widget を捕捉すると override 差し替えに追随しない（既知の禍津）
  List<IncomeEntry> get _entries => widget.entriesOverride ?? widget.entries;

  String get _query => _searchController.text;

  List<IncomeEntry> get _filtered =>
      IncomeAnalysisService.searchBySource(_entries, _query);

  List<IncomeSourceSummary> get _summaries =>
      IncomeAnalysisService.aggregateBySource(_filtered);

  int get _count => IncomeAnalysisService.entryCount(_filtered);

  void _clearQuery() {
    _searchController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEmpty = _entries.isEmpty;

    return Scaffold(
      key: IncomeAnalysisAppKeys.screen,
      appBar: AppBar(
        title: const Text('📈 収入分析'),
        centerTitle: true,
      ),
      body: isEmpty
          ? _buildEmptyState(colorScheme)
          : _buildAnalysisList(colorScheme),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      key: IncomeAnalysisAppKeys.emptyState,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🪙', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text('収入の記録はまだない'),
          const SizedBox(height: 4),
          Text(
            '「収入を記録」から金の由縁を刻め。',
            style: TextStyle(color: colorScheme.outline, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisList(ColorScheme colorScheme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 合計カード
        Card(
          key: IncomeAnalysisAppKeys.totalCard,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('合計収入',
                    style: TextStyle(
                        color: colorScheme.outline, fontSize: 12)),
                Text(
                  IncomeAnalysisService.summaryLabel(_filtered),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // 件数ラベル
        Padding(
          key: IncomeAnalysisAppKeys.countLabel,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            _summaries.isEmpty ? '該当する収入源なし' : '収入源 ${_summaries.length} 件・記録 $_count 件',
            style: TextStyle(color: colorScheme.outline, fontSize: 12),
          ),
        ),
        // 検索フィールド
        TextField(
          key: IncomeAnalysisAppKeys.searchField,
          controller: _searchController,
          decoration: InputDecoration(
            labelText: '収入源で検索',
            hintText: '例: 給与',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    key: IncomeAnalysisAppKeys.searchClearButton,
                    icon: const Icon(Icons.clear),
                    onPressed: _clearQuery,
                  ),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        // 収入源別の行
        for (final summary in _summaries)
          _buildSourceRow(summary, colorScheme),
        if (_summaries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('検索に一致する収入源なし',
                  style: TextStyle(color: colorScheme.outline)),
            ),
          ),
      ],
    );
  }

  Widget _buildSourceRow(
    IncomeSourceSummary summary,
    ColorScheme colorScheme,
  ) {
    return Card(
      key: IncomeAnalysisAppKeys.sourceRow(summary.normalizedSource),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    summary.source,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Text(
                  summary.amountLabel,
                  key: IncomeAnalysisAppKeys.sourceAmount(
                      summary.normalizedSource),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(width: 8),
                Text(
                  summary.ratioLabel,
                  style: TextStyle(color: colorScheme.primary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: summary.ratio,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 4),
            Text(
              '記録 ${summary.count} 件',
              style: TextStyle(color: colorScheme.outline, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
