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

/// 取引の保存データが破損していたため、追記を中止したことを示す例外。
///
/// 内部の生 JSON やキー名などの詳細はメッセージに含めない
/// （呼出側が壊れた文字列を画面表示することを防ぐため）。
class TransactionStorageCorruptException implements Exception {
  /// 人向けの説明文
  final String message;

  const TransactionStorageCorruptException([String? message])
      : message =
            message ?? '保存済みの取引データを照合できなかったため、保存を中止しました';

  @override
  String toString() => message;
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

  /// 破損データの退避キーの接頭辞
  static const String backupKeyPrefix =
      'kozuchi_local_transactions_corrupt_backup_';

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
  ///
  /// 「照合できた時だけ書く」ガード付き。既存データが破損していた場合は
  /// 全件上書きによる履歴消失を避けるため、原本を一切変更せず
  /// [TransactionStorageCorruptException] を投げる（退避のみ行う）。
  Future<List<TransactionModel>> addTransactions(
    List<TransactionModel> transactions,
  ) async {
    final outcome = await loadAllForVerification();
    if (!outcome.verified) {
      // 退避は書込より前。退避に失敗しても原本は変更しないまま中止する。
      await _archiveCorruptRaw();
      throw const TransactionStorageCorruptException();
    }
    final updated = [...outcome.transactions, ...transactions];
    await saveAll(updated);
    return updated;
  }

  /// 破損した保存データを退避キーへ複製する。
  ///
  /// 原本キーは削除・変更しない（復旧の余地を残す）。同一の生文字列が
  /// 既に退避済みなら二重に作らない（冪等）。破損が無ければ何もせず
  /// `false` を返す。例外は握って `false` にする。
  Future<bool> archiveCorruptData() async {
    try {
      final outcome = await loadAllForVerification();
      if (outcome.verified) return false;
      return await _archiveCorruptRaw();
    } catch (_) {
      return false;
    }
  }

  /// 原本の生文字列を退避キーへ複製する（内部用・原本不変）
  Future<bool> _archiveCorruptRaw() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return false;

      // 同一 raw が退避済みなら何もしない（冪等）
      for (final key in prefs.getKeys()) {
        if (!key.startsWith(backupKeyPrefix)) continue;
        if (prefs.getString(key) == raw) return false;
      }

      final stamp = DateTime.now().microsecondsSinceEpoch;
      await prefs.setString('$backupKeyPrefix$stamp', raw);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 全取引を削除する
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
