import 'package:kozuchi/domain/models/aggregation_result.dart';
import 'package:kozuchi/domain/models/advisor.dart';
import 'package:kozuchi/domain/services/expense_aggregation_service.dart';
import 'package:kozuchi/domain/services/expense_repository.dart';
import 'weekly_report.dart';

/// 週間レポート生成サービス
///
/// 支出集計データを元に、SATORI変動とアドバイザー助言を含む
/// 週間レポートを生成する。
class WeeklyReportService {
  final ExpenseAggregationService _aggregationService;

  /// アドバイザー情報（nullの場合は汎用助言）
  final Advisor? advisor;

  WeeklyReportService({
    required ExpenseRepository repository,
    this.advisor,
  }) : _aggregationService = ExpenseAggregationService(repository);

  /// 指定日を含む週のレポートを生成する
  Future<WeeklyReport> generate(DateTime referenceDate) async {
    final result = await _aggregationService.getWeeklySummary(referenceDate);

    return _buildReport(result);
  }

  /// 集計結果からレポートを構築
  WeeklyReport _buildReport(AggregationResult result) {
    final period = result.period;
    final current = result.current;
    final comparison = result.comparison;

    // 週ラベルを生成（ISO 8601 週番号形式）
    final weekLabel = _formatWeekLabel(period.start);

    // TOP3カテゴリ
    final top3 = current.byCategory.take(3).map((c) {
      return WeeklyReportCategory(
        category: c.category,
        amount: c.amount,
        percentage: c.percentage,
      );
    }).toList();

    // SATORI変動の計算（支出減少→SATORI上昇、支出増加→SATORI低下）
    final satoriChange = _computeSatoriChange(comparison.totalChange);
    final satoriChangeLabel = _formatSatoriChangeLabel(
      comparison.totalChangePercent,
    );

    // アドバイザー助言の生成
    final advice = _generateAdvice(top3, comparison);

    return WeeklyReport(
      weekLabel: weekLabel,
      totalSpending: current.total,
      topCategories: top3,
      satoriChange: satoriChange,
      satoriChangeLabel: satoriChangeLabel,
      advisorAdvice: advice,
      advisorEmoji: advisor?.emoji,
      advisorName: advisor?.label,
    );
  }

  /// ISO週番号形式のラベルを生成
  String _formatWeekLabel(DateTime weekStart) {
    // 簡易的な週番号計算（月曜始まり）
    final year = weekStart.year;
    // その年の第1月曜日を計算
    final jan1 = DateTime(year, 1, 1);
    final firstMonday = jan1.add(Duration(days: (8 - jan1.weekday) % 7));
    final weekNum =
        ((weekStart.difference(firstMonday).inDays) / 7).floor() + 1;
    return '$year-W${weekNum.toString().padLeft(2, '0')}';
  }

  /// SATORI変動値を計算（支出減→プラス、支出増→マイナス）
  int _computeSatoriChange(int totalChange) {
    // 支出減少（totalChange < 0）はSATORI上昇
    // 支出増加（totalChange > 0）はSATORI低下
    // 変化が小さい場合は±0
    if (totalChange.abs() < 1000) return 0;
    // 1000円あたり±1 SATORI（上限±10）
    final raw = (-totalChange / 1000).round();
    return raw.clamp(-10, 10);
  }

  /// SATORI変動ラベルを生成
  String _formatSatoriChangeLabel(double changePercent) {
    final absPercent = changePercent.abs();
    if (absPercent < 1.0) return '先週とほぼ同じ';
    final sign = changePercent > 0 ? '+' : '';
    final direction = changePercent < 0 ? '減少' : '増加';
    return '$direction $sign${absPercent.toStringAsFixed(1)}%';
  }

  /// アドバイザー助言を生成
  String _generateAdvice(
    List<WeeklyReportCategory> topCategories,
    PeriodComparison comparison,
  ) {
    if (topCategories.isEmpty) {
      return '今週は支出の記録がまだありません。\n支出を記録して、お金の流れを可視化しましょう。';
    }

    final topCat = topCategories.first;
    final totalChange = comparison.totalChange;
    final isDecrease = totalChange < 0;
    final isIncrease = totalChange > 0;

    // アドバイザー別の助言
    if (advisor != null) {
      return _advisorSpecificAdvice(
        topCat.category,
        isDecrease,
        isIncrease,
        totalChange,
      );
    }

    // 汎用助言
    final changeDesc = isDecrease
        ? '支出が先週より¥${totalChange.abs()}減少しました。節約の成果が出ていますね。'
        : isIncrease
            ? '支出が先週より¥$totalChange増加しました。来週は「${topCat.category}」に注意してみましょう。'
            : '先週とほぼ同じ支出水準です。安定した金銭管理ができています。';

    return '$changeDesc\n'
        '今週の支出TOPは「${topCat.category}」（¥${topCat.amount}）でした。';
  }

  /// アドバイザー別の個別助言
  String _advisorSpecificAdvice(
    String topCategory,
    bool isDecrease,
    bool isIncrease,
    int totalChange,
  ) {
    final prefix = '${advisor!.emoji} ${advisor!.label} より:\n';
    final absChange = totalChange.abs();

    return switch (advisor!) {
      Advisor.daikokuten => isDecrease
          ? '$prefix支出¥$absChange減。よくぞ福を守った。来週も「$topCategory」に気を配れ。福は日々の小さな選択に宿る。'
          : '$prefix支出¥$absChange増。されど恐るるに及ばず。「$topCategory」は明日の福への布施と心得よ。',
      Advisor.benzaiten => isDecrease
          ? '$prefix¥${absChange}の節約、見事です。浮いた資金を学びに回せば、さらに高みへ。'
          : '$prefix¥$absChangeの支出増。しかし「$topCategory」への投資はあなたを成長させる糧。恐れず、されど見極めを。',
      Advisor.bishamonten => isDecrease
          ? '$prefix¥${absChange}の支出減、戦略的撤退と見た。「$topCategory」への資源配分、見事なり。'
          : '$prefix¥$absChangeの支出増。これは攻めの一手か、それとも無駄打ちか。よく見極めよ。',
      Advisor.kichijoten => isDecrease
          ? '$prefix¥${absChange}の節約、心身のバランスが整ってきた証。「$topCategory」もほどほどが美しき調和。'
          : '$prefix¥$absChangeの支出増。されど心が潤うなら良し。「$topCategory」があなたを輝かせているならば。',
    };
  }
}
