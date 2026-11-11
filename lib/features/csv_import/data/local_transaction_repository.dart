import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/domain/models/transaction_model.dart';

/// 取引の読込結果（照合可否つき）。
///
/// [verified] が true のとき [transactions] は保存内容を正しく復元したもの。
/// false のときは保存データを読めなかった（空リストは「0件」ではなく
/// 「不明」を意味する）。
class TransactionLoadOutcome {
  /// 復元した取引一覧
  final List<TransactionModel> transactions;

  /// 保存データを正しく読めたか
  final bool verified;

  const TransactionLoadOutcome({
    required this.transactions,
    required this.verified,
  });
}

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
  ///
  /// 破損データは空リストとして扱う（従来通りの挙動）。
  Future<List<TransactionModel>> loadAll() async {
    final outcome = await loadAllForVerification();
    return outcome.transactions;
  }

  /// 保存済みの全取引を「照合可否つき」で取得する。
  ///
  /// - キー不在 → verified: true, []
  /// - JSON デコード成功 → verified: true, 復元リスト
  /// - デコード失敗／型不正／SharedPreferences 例外 → verified: false, []
  Future<TransactionLoadOutcome> loadAllForVerification() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_key);
      if (jsonString == null) {
        return const TransactionLoadOutcome(
          transactions: <TransactionModel>[],
          verified: true,
        );
      }
      final decoded = jsonDecode(jsonString);
      if (decoded is! List) {
        return const TransactionLoadOutcome(
          transactions: <TransactionModel>[],
          verified: false,
        );
      }
      final restored = <TransactionModel>[];
      for (final e in decoded) {
        if (e is! Map<String, dynamic>) {
          return const TransactionLoadOutcome(
            transactions: <TransactionModel>[],
            verified: false,
          );
        }
        restored.add(TransactionModel.fromJson(e));
      }
      return TransactionLoadOutcome(transactions: restored, verified: true);
    } catch (_) {
      // 破損データ・環境例外は「照合できなかった」として扱う
      return const TransactionLoadOutcome(
        transactions: <TransactionModel>[],
        verified: false,
      );
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
