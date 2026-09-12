import 'package:kozuchi/features/wallet/domain/models/wallet.dart';

/// 財布の入出金ログ1件
///
/// [amount] は符号付きの円額。正なら入金（チャージ・振込）、負なら出金（支出）。
/// 0 は意味を持たないため許容しない。I/O を持たない不変（immutable）モデル。
class WalletMovement {
  /// 一意な識別子
  final String id;

  /// 対象の財布ID
  final String walletId;

  /// 符号付き金額（円、0以外）
  final int amount;

  /// メモ（例: 「ATM入金」「スーパー」）
  final String note;

  /// 発生日時
  final DateTime date;

  const WalletMovement({
    required this.id,
    required this.walletId,
    required this.amount,
    this.note = '',
    required this.date,
  }) : assert(amount != 0, '金額0の入出金は記録できません');

  /// 入金かどうか
  bool get isIncome => amount > 0;

  /// 出金かどうか
  bool get isExpense => amount < 0;

  /// 出金額の絶対値（入金の場合は0）
  int get expenseAmount => amount < 0 ? -amount : 0;

  /// 入金額（出金の場合は0）
  int get incomeAmount => amount > 0 ? amount : 0;

  /// 一部を差し替えたコピーを返す
  WalletMovement copyWith({
    String? walletId,
    int? amount,
    String? note,
    DateTime? date,
  }) {
    return WalletMovement(
      id: id,
      walletId: walletId ?? this.walletId,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      date: date ?? this.date,
    );
  }

  /// 入出金ログを作る補助（符号なし金額と種別から組み立てる）
  ///
  /// [isIncome] が true なら正、false なら負の符号を付けて [amount] を記録する。
  factory WalletMovement.signed({
    required String id,
    required String walletId,
    required int amount,
    required bool isIncome,
    String note = '',
    required DateTime date,
  }) {
    return WalletMovement(
      id: id,
      walletId: walletId,
      amount: isIncome ? amount.abs() : -amount.abs(),
      note: note,
      date: date,
    );
  }

  factory WalletMovement.fromJson(Map<String, dynamic> json) {
    return WalletMovement(
      id: json['id'] as String? ?? '',
      walletId: json['walletId'] as String? ?? '',
      amount: json['amount'] as int? ?? 0,
      note: json['note'] as String? ?? '',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'walletId': walletId,
      'amount': amount,
      'note': note,
      'date': date.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) => other is WalletMovement && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'WalletMovement(id: $id, walletId: $walletId, amount: $amount, '
      'note: $note)';
}

/// 財布と入出金ログの対応を扱う補助（ドメイン内の純粋関数）
extension WalletMovementList on List<WalletMovement> {
  /// 指定財布の入出金ログを日付降順（同日はID昇順）で返す
  List<WalletMovement> forWallet(String walletId) {
    final filtered = where((m) => m.walletId == walletId).toList()
      ..sort((a, b) {
        final byDate = b.date.compareTo(a.date);
        return byDate != 0 ? byDate : a.id.compareTo(b.id);
      });
    return List.unmodifiable(filtered);
  }

  /// 指定財布の合計入金額（円）
  int incomeOf(String walletId) => fold(
        0,
        (sum, m) => m.walletId == walletId && m.isIncome ? sum + m.amount : sum,
      );

  /// 指定財布の合計出金額（正の円）
  int expenseOf(String walletId) => fold(
        0,
        (sum, m) =>
            m.walletId == walletId && m.isExpense ? sum - m.amount : sum,
      );
}

/// 財布IDの集合に含まれないログを除く（未所有の入出金は無視する）
List<WalletMovement> movementsOfWallets(
  List<WalletMovement> movements,
  Iterable<String> walletIds,
) {
  final ids = walletIds.toSet();
  return List.unmodifiable(
    movements.where((m) => ids.contains(m.walletId)),
  );
}

/// [Wallet] のリストからID集合を作る
Set<String> walletIdsOf(List<Wallet> wallets) =>
    {for (final wallet in wallets) wallet.id};
