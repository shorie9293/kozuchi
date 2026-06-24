/// 週間レポート用データモデル
///
/// 週間レポート画面に表示する集約データ。
/// 支出集計に加え、SATORI変動とアドバイザーからの助言を含む。

/// 週間レポートのカテゴリエントリ
class WeeklyReportCategory {
  final String category;
  final int amount;
  final double percentage;

  const WeeklyReportCategory({
    required this.category,
    required this.amount,
    required this.percentage,
  });
}

/// 週間レポート全体
class WeeklyReport {
  /// 週ラベル（例: "2026-W25"）
  final String weekLabel;

  /// 総支出額
  final int totalSpending;

  /// 支出カテゴリTOP3
  final List<WeeklyReportCategory> topCategories;

  /// SATORI変動値（正=増加, 負=減少）
  final int satoriChange;

  /// SATORI変動の表示ラベル
  final String satoriChangeLabel;

  /// アドバイザーの助言テキスト
  final String advisorAdvice;

  /// アドバイザーの絵文字（未契約はnull）
  final String? advisorEmoji;

  /// アドバイザー名（未契約はnull）
  final String? advisorName;

  const WeeklyReport({
    required this.weekLabel,
    required this.totalSpending,
    required this.topCategories,
    required this.satoriChange,
    required this.satoriChangeLabel,
    required this.advisorAdvice,
    this.advisorEmoji,
    this.advisorName,
  });

  /// SATORI変動の方向を表すアイコン
  String get satoriIcon {
    if (satoriChange > 0) return '📈';
    if (satoriChange < 0) return '📉';
    return '➡️';
  }

  /// SATORI変動の色（増加=緑, 減少=赤, 変化なし=灰）
  String get satoriColorHint {
    if (satoriChange > 0) return 'positive';
    if (satoriChange < 0) return 'negative';
    return 'neutral';
  }

  /// API応答（GET /api/weekly-report）からWeeklyReportを生成
  factory WeeklyReport.fromApiJson(Map<String, dynamic> json) {
    final topCategories = (json['top_categories'] as List<dynamic>?)
            ?.map((c) => WeeklyReportCategory(
                  category: c['category'] as String? ?? '',
                  amount: c['amount'] as int? ?? 0,
                  percentage: (c['percentage'] as num?)?.toDouble() ?? 0.0,
                ))
            .toList() ??
        [];

    final satori = json['satori'] as Map<String, dynamic>?;
    final deltaPercent = (satori?['delta_percent'] as num?)?.toDouble() ?? 0;
    final satoriSymbol = satori?['symbol'] as String? ?? '→';
    final satoriMessage = satori?['message'] as String? ?? '';

    final summary = json['summary'] as Map<String, dynamic>?;

    return WeeklyReport(
      weekLabel: json['week'] as String? ?? '',
      totalSpending: summary?['total_expense'] as int? ?? 0,
      topCategories: topCategories,
      satoriChange: deltaPercent.round(),
      satoriChangeLabel: '$satoriSymbol $satoriMessage',
      advisorAdvice: json['advice'] as String? ?? '',
    );
  }
}
