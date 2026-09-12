import 'package:kozuchi/features/wallet/domain/models/wallet.dart';
import 'package:kozuchi/features/wallet/domain/models/wallet_movement.dart';

/// 財布1つ分の残高集計結果
class WalletBalance {
  /// 対象の財布
  final Wallet wallet;

  /// 合計入金額（円、0以上）
  final int income;

  /// 合計出金額（円、0以上）
  final int expense;

  const WalletBalance({
    required this.wallet,
    this.income = 0,
    this.expense = 0,
  });

  /// 現在残高（初期残高 + 入金 − 出金）
  int get balance => wallet.initialBalance + income - expense;

  /// 入出金による増減（入金 − 出金）
  int get netChange => income - expense;

  /// 残高がマイナスか（クレジット等で起こり得る）
  bool get isNegative => balance < 0;

  /// 入出金ログが1件も無いか
  bool get isEmpty => income == 0 && expense == 0;

  @override
  String toString() =>
      'WalletBalance(${wallet.name}: income=$income, expense=$expense, '
      'balance=$balance)';
}

/// 全財布の残高集計
class WalletSummary {
  /// 財布ごとの残高（残高降順・同額はID昇順）
  final List<WalletBalance> balances;

  const WalletSummary(this.balances);

  /// 空の集計（財布が1つも無い）
  static const WalletSummary empty = WalletSummary([]);

  /// 財布が1つも無いか
  bool get isEmpty => balances.isEmpty;

  /// 合計残高（円）
  int get totalBalance =>
      balances.fold(0, (sum, entry) => sum + entry.balance);

  /// 合計入金額（円）
  int get totalIncome => balances.fold(0, (sum, entry) => sum + entry.income);

  /// 合計出金額（円）
  int get totalExpense => balances.fold(0, (sum, entry) => sum + entry.expense);

  /// 指定財布の集計を返す（無ければ null）
  WalletBalance? balanceOf(String walletId) {
    for (final entry in balances) {
      if (entry.wallet.id == walletId) return entry;
    }
    return null;
  }

  /// 指定種別の合計残高（円）
  int totalBalanceOfType(WalletType type) => balances
      .where((entry) => entry.wallet.type == type)
      .fold(0, (sum, entry) => sum + entry.balance);

  /// 残高がマイナスの財布（警告表示用）
  List<WalletBalance> get negativeWallets =>
      List.unmodifiable(balances.where((entry) => entry.isNegative));

  /// 種別ごとの合計残高（[WalletType.values] の順・金額が0の種別も含む）
  Map<WalletType, int> get totalsByType => {
        for (final type in WalletType.values) type: totalBalanceOfType(type),
      };
}

/// 財布残高の集計サービス（純粋ロジック・I/O なし）
class WalletService {
  const WalletService._();

  /// 財布と入出金ログから残高集計を組み立てる。
  ///
  /// - 未所有の財布IDを持つログは無視する
  /// - 並び順は残高降順、同額は財布ID昇順（表示順を決定的にするため）
  static WalletSummary compute({
    required List<Wallet> wallets,
    required List<WalletMovement> movements,
  }) {
    if (wallets.isEmpty) return WalletSummary.empty;

    final owned = movementsOfWallets(movements, walletIdsOf(wallets));

    final balances = <WalletBalance>[
      for (final wallet in wallets)
        WalletBalance(
          wallet: wallet,
          income: owned.incomeOf(wallet.id),
          expense: owned.expenseOf(wallet.id),
        ),
    ];

    balances.sort((a, b) {
      final byBalance = b.balance.compareTo(a.balance);
      return byBalance != 0
          ? byBalance
          : a.wallet.id.compareTo(b.wallet.id);
    });

    return WalletSummary(List.unmodifiable(balances));
  }

  /// 指定財布の入出金ログを新しい順で返す（純粋関数）
  static List<WalletMovement> movementsFor(
    List<WalletMovement> movements,
    String walletId,
  ) {
    if (walletId.isEmpty) return const [];
    return movements.forWallet(walletId);
  }
}
