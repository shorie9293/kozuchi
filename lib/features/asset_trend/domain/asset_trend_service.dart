import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/asset_trend/domain/monthly_asset_point.dart';

/// 資産推移の集計サマリー。
///
/// [AssetTrendService.summarize] が生成する。グラフ上部の指標表示に用いる。
class AssetTrendSummary {
  /// 直近月の累積残高
  final int latestBalance;

  /// 対象期間の収入合計
  final int totalIncome;

  /// 対象期間の支出合計
  final int totalExpense;

  /// 対象月数
  final int months;

  /// 純増減が最大の月（同値なら最初の月）
  final MonthlyAssetPoint? bestMonth;

  /// 純増減が最小の月（同値なら最初の月）
  final MonthlyAssetPoint? worstMonth;

  const AssetTrendSummary({
    required this.latestBalance,
    required this.totalIncome,
    required this.totalExpense,
    required this.months,
    this.bestMonth,
    this.worstMonth,
  });

  /// 対象期間の純増減（収入 − 支出）
  int get totalNetChange => totalIncome - totalExpense;

  /// 月あたり平均の純増減
  double get averageMonthlyNet => months == 0 ? 0 : totalNetChange / months;

  /// データが空か
  bool get isEmpty => months == 0;

  @override
  String toString() => 'AssetTrendSummary(latest=$latestBalance, '
      'income=$totalIncome, expense=$totalExpense, months=$months)';
}

/// 資産推移（残高・月次純資産）の集計サービス。
///
/// [TransactionModel]（amount の符号で収入=正 / 支出=負）から、
/// 月次の累積残高推移を純粋計算で構築する。永続化は行わない。
class AssetTrendService {
  /// デフォルトの集計月数
  static const int defaultMonths = 12;

  const AssetTrendService();

  /// 取引一覧から直近 [months] ヶ月分の月次資産推移を構築する。
  ///
  /// - **累積残高**は全期間の取引を対象に計算する（期間の先頭で 0 にリセットしない）。
  ///   これにより、途中から表示しても残高の絶対値が正しく保たれる。
  /// - 返却は昇順（古い月 → 新しい月）。窓の外の月・日付不正の取引は無視する。
  /// - [now] を省略すると [DateTime.now] を基準月とする（テスト用に注入可能）。
  List<MonthlyAssetPoint> buildMonthlyTrend(
    List<TransactionModel> transactions, {
    DateTime? now,
    int months = defaultMonths,
  }) {
    if (months < 1) return const [];

    final reference = now ?? DateTime.now();

    // 月ごとに収入・支出を集計（キー = 年 * 12 + (月 - 1)）
    final buckets = <int, _MonthBucket>{};
    for (final tx in transactions) {
      final date = DateTime.tryParse(tx.datetime);
      if (date == null) continue;
      final bucket = buckets.putIfAbsent(
        date.year * 12 + (date.month - 1),
        () => _MonthBucket(date.year, date.month),
      );
      if (tx.amount >= 0) {
        bucket.income += tx.amount;
      } else {
        bucket.expense += -tx.amount;
      }
    }
    if (buckets.isEmpty) return const [];

    // 昇順に累積残高を計算（全期間対象）
    final sortedKeys = buckets.keys.toList()..sort();
    var running = 0;
    final all = <MonthlyAssetPoint>[];
    for (final key in sortedKeys) {
      final bucket = buckets[key]!;
      running += bucket.income - bucket.expense;
      all.add(MonthlyAssetPoint(
        year: bucket.year,
        month: bucket.month,
        income: bucket.income,
        expense: bucket.expense,
        balance: running,
      ));
    }

    // 基準月を末尾とする直近 [months] ヶ月に限定
    final referenceKey = reference.year * 12 + (reference.month - 1);
    final startKey = referenceKey - (months - 1);
    return all
        .where((p) => p.key >= startKey && p.key <= referenceKey)
        .toList();
  }

  /// 月次推移からサマリーを生成する。空リストなら [AssetTrendSummary.isEmpty] が true。
  AssetTrendSummary summarize(List<MonthlyAssetPoint> points) {
    if (points.isEmpty) {
      return const AssetTrendSummary(
        latestBalance: 0,
        totalIncome: 0,
        totalExpense: 0,
        months: 0,
      );
    }

    var income = 0;
    var expense = 0;
    MonthlyAssetPoint? best;
    MonthlyAssetPoint? worst;
    for (final p in points) {
      income += p.income;
      expense += p.expense;
      if (best == null || p.netChange > best.netChange) best = p;
      if (worst == null || p.netChange < worst.netChange) worst = p;
    }

    return AssetTrendSummary(
      latestBalance: points.last.balance,
      totalIncome: income,
      totalExpense: expense,
      months: points.length,
      bestMonth: best,
      worstMonth: worst,
    );
  }
}

/// 月次集計の内部作業用バケット。
class _MonthBucket {
  final int year;
  final int month;
  int income = 0;
  int expense = 0;

  _MonthBucket(this.year, this.month);
}
