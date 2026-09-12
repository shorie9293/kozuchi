import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:kozuchi/features/wallet/domain/models/wallet.dart';
import 'package:kozuchi/features/wallet/domain/models/wallet_movement.dart';
import 'package:kozuchi/features/wallet/domain/wallet_service.dart';

/// 財布と入出金ログの永続化リポジトリ
///
/// SharedPreferences に JSON 文字列として保存する。
/// - 財布定義: `kozuchi_wallets`
/// - 入出金ログ: `kozuchi_wallet_movements`
///
/// 破損データは空として扱い、例外を投げない。
class WalletRepository {
  static const String walletsKey = 'kozuchi_wallets';
  static const String movementsKey = 'kozuchi_wallet_movements';

  const WalletRepository();

  // ── 財布 ─────────────────────────────────────────

  /// 財布一覧を読み出す（未保存・破損時は空リスト）。
  Future<List<Wallet>> loadWallets() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(walletsKey);
    if (jsonString == null) return const [];

    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! List) return const [];
      final wallets = <Wallet>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final wallet = Wallet.fromJson(item);
          if (wallet.id.isNotEmpty) wallets.add(wallet);
        } else if (item is Map) {
          final wallet = Wallet.fromJson(Map<String, dynamic>.from(item));
          if (wallet.id.isNotEmpty) wallets.add(wallet);
        }
      }
      return List.unmodifiable(wallets);
    } catch (_) {
      return const [];
    }
  }

  /// 財布一覧を保存する。
  Future<void> saveWallets(List<Wallet> wallets) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      walletsKey,
      jsonEncode(wallets.map((w) => w.toJson()).toList()),
    );
  }

  /// 財布を追加する（同一IDは置換）。更新後の一覧を返す。
  ///
  /// 名前が空白のみ、または初期残高が負の場合は [ArgumentError]。
  Future<List<Wallet>> addWallet({
    required String name,
    WalletType type = WalletType.cash,
    int initialBalance = 0,
    int? colorValue,
    String? id,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', '財布名を空にはできません');
    }
    if (initialBalance < 0) {
      throw ArgumentError.value(
        initialBalance,
        'initialBalance',
        '初期残高は0以上である必要があります',
      );
    }
    final wallets = await loadWallets();
    final wallet = Wallet(
      id: id ?? 'wallet_${DateTime.now().microsecondsSinceEpoch}',
      name: trimmed,
      type: type,
      initialBalance: initialBalance,
      colorValue: colorValue ?? Wallet.defaultColorValue,
    );
    final updated = [...wallets.where((w) => w.id != wallet.id), wallet];
    await saveWallets(updated);
    return List.unmodifiable(updated);
  }

  /// 財布の名前を変更する（存在しないIDは変更なし）。更新後の一覧を返す。
  Future<List<Wallet>> renameWallet(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', '財布名を空にはできません');
    }
    final wallets = await loadWallets();
    final updated = [
      for (final wallet in wallets)
        wallet.id == id ? wallet.copyWith(name: trimmed) : wallet,
    ];
    await saveWallets(updated);
    return List.unmodifiable(updated);
  }

  /// 財布を削除する。その財布の入出金ログも同時に削除する。
  ///
  /// 更新後の一覧を返す。
  Future<List<Wallet>> removeWallet(String id) async {
    final wallets = await loadWallets();
    final updated = wallets.where((w) => w.id != id).toList();
    await saveWallets(updated);

    final movements = await loadMovements();
    final remaining = movements.where((m) => m.walletId != id).toList();
    if (remaining.length != movements.length) {
      await saveMovements(remaining);
    }
    return List.unmodifiable(updated);
  }

  // ── 入出金ログ ───────────────────────────────────

  /// 全入出金ログを読み出す（未保存・破損時は空リスト）。
  Future<List<WalletMovement>> loadMovements() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(movementsKey);
    if (jsonString == null) return const [];

    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! List) return const [];
      final movements = <WalletMovement>[];
      for (final item in decoded) {
        final map = item is Map<String, dynamic>
            ? item
            : (item is Map ? Map<String, dynamic>.from(item) : null);
        if (map == null) continue;
        // 金額0・ID欠落のレコードはモデルの不変条件を満たさないため読み飛ばす
        final id = map['id'];
        final amount = map['amount'];
        if (id is! String || id.isEmpty) continue;
        if (amount is! int || amount == 0) continue;
        movements.add(WalletMovement.fromJson(map));
      }
      return List.unmodifiable(movements);
    } catch (_) {
      return const [];
    }
  }

  /// 入出金ログを保存する。
  Future<void> saveMovements(List<WalletMovement> movements) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      movementsKey,
      jsonEncode(movements.map((m) => m.toJson()).toList()),
    );
  }

  /// 入出金を1件記録する。更新後のログ一覧を返す。
  ///
  /// 財布IDが空、または金額が0の場合は [ArgumentError]。
  Future<List<WalletMovement>> addMovement({
    required String walletId,
    required int amount,
    String note = '',
    required DateTime date,
    String? id,
  }) async {
    if (walletId.trim().isEmpty) {
      throw ArgumentError.value(walletId, 'walletId', '財布IDを空にはできません');
    }
    if (amount == 0) {
      throw ArgumentError.value(amount, 'amount', '金額0の入出金は記録できません');
    }
    final movements = await loadMovements();
    final movement = WalletMovement(
      id: id ?? 'movement_${DateTime.now().microsecondsSinceEpoch}',
      walletId: walletId,
      amount: amount,
      note: note.trim(),
      date: date,
    );
    final updated = [
      ...movements.where((m) => m.id != movement.id),
      movement,
    ];
    await saveMovements(updated);
    return List.unmodifiable(updated);
  }

  /// 入出金ログを削除する。更新後のログ一覧を返す。
  Future<List<WalletMovement>> removeMovement(String id) async {
    final movements = await loadMovements();
    final updated = movements.where((m) => m.id != id).toList();
    await saveMovements(updated);
    return List.unmodifiable(updated);
  }

  /// 指定財布の入出金ログを新しい順で返す。
  Future<List<WalletMovement>> movementsFor(String walletId) async {
    final movements = await loadMovements();
    return WalletService.movementsFor(movements, walletId);
  }
}
