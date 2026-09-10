/// 月次の資産推移を表す不変モデル。
///
/// [balance] は「その月末時点の累積残高」で、全取引の累積
/// （収入 − 支出）から算出される。単月の増減は [netChange] を参照。
class MonthlyAssetPoint {
  /// 年（例: 2026）
  final int year;

  /// 月（1〜12）
  final int month;

  /// 当月の収入合計（正の値）
  final int income;

  /// 当月の支出合計（正の絶対値）
  final int expense;

  /// 当月末時点の累積残高（全期間の収入 − 支出の累積）
  final int balance;

  const MonthlyAssetPoint({
    required this.year,
    required this.month,
    required this.income,
    required this.expense,
    required this.balance,
  });

  /// 当月の純増減（収入 − 支出）
  int get netChange => income - expense;

  /// 時系列ソート・比較用の月キー（`年 * 12 + (月 - 1)`）
  int get key => year * 12 + (month - 1);

  /// `YYYY/MM` 形式のラベル
  String get label => '$year/${month.toString().padLeft(2, '0')}';

  @override
  String toString() =>
      'MonthlyAssetPoint($label: income=$income, expense=$expense, '
      'balance=$balance, net=$netChange)';
}
