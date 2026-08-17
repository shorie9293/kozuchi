import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/domain/models/transaction_model.dart';

/// ローカル取引の永続化リポジトリ
///
/// CSVインポートした取引や定期取引から自動生成された取引を
/// SharedPreferences に保存・復元する。既存の ExpenditureRepository /
/// PlayerRepository と同様のパターンを踏襲する。
///
/// キーは `kozuchi_local_transactions`。
class LocalTransactionRepository {
  static const String _key = 'kozuchi_local_transactions';

  const LocalTransactionRepository();

  /// 保存済みの全取引を取得する
  Future<List<TransactionModel>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString == null) return [];
    try {
      final list = jsonDecode(jsonString) as List<dynamic>;
      return list
          .map((e) => TransactionModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // 破損データは空リストとして扱う
      return [];
    }
  }

  /// 取引一覧を丸ごと保存する
  Future<void> saveAll(List<TransactionModel> transactions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(transactions.map((t) => t.toJson()).toList()),
    );
  }

  /// 既存の取引一覧に追記し、更新後の一覧を返す
  Future<List<TransactionModel>> addTransactions(
    List<TransactionModel> transactions,
  ) async {
    final current = await loadAll();
    final updated = [...current, ...transactions];
    await saveAll(updated);
    return updated;
  }

  /// 全取引を削除する
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
