import 'package:flutter/material.dart';
import 'package:kozuchi/features/weekly_report/data/weekly_report.dart';
import 'package:kozuchi/features/weekly_report/data/weekly_report_api_service.dart';
import 'package:kozuchi/features/weekly_report/data/weekly_report_service.dart';
import 'package:kozuchi/domain/services/expense_repository.dart';
import 'package:kozuchi/domain/services/expense_repository_impl.dart';

/// 週間レポート画面
///
/// 今週の支出集計TOP3・SATORI変動・アドバイザー助言を表示する。
/// バックボタン・ローディング・エラー状態を完備。
///
/// デフォルトでは kozuchi サーバーAPI（GET /api/weekly-report）から
/// データを取得する。[repository] を注入するとローカル集計モードに切替。
class WeeklyReportScreen extends StatefulWidget {
  /// APIサービス（テスト時に注入可能）
  final WeeklyReportApiService? apiService;

  /// 支出リポジトリ（テスト時に注入可能、ローカル集計モード用）
  final ExpenseRepository? repository;

  /// 表示する週ラベル（例: "2026-W25"）。nullの場合は現在の週。
  final String? week;

  const WeeklyReportScreen({
    super.key,
    this.apiService,
    this.repository,
    this.week,
  });

  @override
  State<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends State<WeeklyReportScreen> {
  bool _isLoading = true;
  WeeklyReport? _report;
  String? _error;

  bool get _useApi => widget.repository == null;

  WeeklyReportService get _localService => WeeklyReportService(
        repository: widget.repository ?? InMemoryExpenseRepository(),
      );

  WeeklyReportApiService get _apiService =>
      widget.apiService ?? WeeklyReportApiService();

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final WeeklyReport report;
      if (_useApi) {
        report = await _apiService.fetchReport(week: widget.week);
      } else {
        report = await _localService.generate(DateTime.now());
      }
      if (mounted) {
        setState(() {
          _report = report;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.week != null ? '週間レポート (${widget.week})' : '週間レポート'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(colorScheme),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return _buildErrorState(colorScheme);
    }

    final report = _report;
    if (report == null || report.topCategories.isEmpty) {
      return _buildEmptyState(colorScheme);
    }

    return _buildReportContent(report, colorScheme);
  }

  Widget _buildErrorState(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: 12),
            Text(
              'レポートの取得に失敗しました',
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _loadReport,
              icon: const Icon(Icons.refresh),
              label: const Text('再試行'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              '今週の支出データはまだありません',
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '支出を記録すると、週間レポートが表示されます',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportContent(WeeklyReport report, ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 週ラベルヘッダー
          _buildWeekHeader(report, colorScheme),
          const SizedBox(height: 16),

          // SATORI変動カード
          _buildSatoriCard(report, colorScheme),
          const SizedBox(height: 16),

          // 支出TOP3
          _buildTopCategoriesCard(report, colorScheme),
          const SizedBox(height: 16),

          // アドバイザー助言
          _buildAdviceCard(report, colorScheme),
        ],
      ),
    );
  }

  /// 週ラベル + 総支出ヘッダー
  Widget _buildWeekHeader(WeeklyReport report, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.7),
            colorScheme.secondaryContainer.withValues(alpha: 0.4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            report.weekLabel,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '¥${report.totalSpending}',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '今週の総支出',
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// SATORI変動カード
  Widget _buildSatoriCard(WeeklyReport report, ColorScheme colorScheme) {
    final isPositive = report.satoriChange > 0;
    final isNegative = report.satoriChange < 0;
    final changeColor = isPositive
        ? Colors.green.shade400
        : isNegative
            ? Colors.red.shade400
            : colorScheme.onSurfaceVariant;
    final changeText = report.satoriChange >= 0
        ? '+${report.satoriChange}'
        : '${report.satoriChange}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  report.satoriIcon,
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 8),
                Text(
                  'SATORI変動',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: changeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    changeText,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: changeColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              report.satoriChangeLabel,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 支出TOP3カード
  Widget _buildTopCategoriesCard(WeeklyReport report, ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📊 支出TOP3',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            if (report.topCategories.isEmpty)
              Text(
                'データがありません',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              )
            else
              ...report.topCategories.asMap().entries.map(
                    (entry) => _buildCategoryRow(
                      index: entry.key,
                      category: entry.value,
                      colorScheme: colorScheme,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  /// カテゴリ行
  Widget _buildCategoryRow({
    required int index,
    required WeeklyReportCategory category,
    required ColorScheme colorScheme,
  }) {
    final rankEmoji = switch (index) {
      0 => '🥇',
      1 => '🥈',
      2 => '🥉',
      _ => '  ',
    };

    // 全体の支出に対する割合バー
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  rankEmoji,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              Expanded(
                child: Text(
                  category.category,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                '¥${category.amount}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${category.percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // プログレスバー
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: category.percentage / 100.0,
              minHeight: 6,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                index == 0
                    ? Colors.amber.shade400
                    : index == 1
                        ? Colors.grey.shade400
                        : Colors.brown.shade300,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// アドバイザー助言カード
  Widget _buildAdviceCard(WeeklyReport report, ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  report.advisorEmoji ?? '💡',
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 8),
                Text(
                  report.advisorName ?? 'アドバイザー',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Text(' より'),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                report.advisorAdvice,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
