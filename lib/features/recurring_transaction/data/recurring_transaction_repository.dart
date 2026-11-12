import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/features/recurring_transaction/domain/recurring_storage_result.dart';
import 'package:kozuchi/features/recurring_transaction/domain/recurring_transaction.dart';

/// 定期取引定義と生成進捗の永続化リポジトリ
///
/// 定義一覧（`kozuchi_recurring_defs`）と、定義IDごとの
/// 最終生成日時（`kozuchi_recurring_last_generated`）を保存する。
///
/// **破損した保存データは「0件」ではない。** 読み取りは
/// [RecurringDefinitionsLoadResult] / [RecurringLastGeneratedResult] で
/// `verified` を伴って返し、`verified == false` の間は上書き保存を拒む
/// （空リストを信じて保存すると、その1回で既存定義が恒久消失する）。
class RecurringTransactionRepository {
  static const String _defsKey = 'kozuchi_recurring_defs';
  static const String _lastGenKey = 'kozuchi_recurring_last_generated';

  /// 破損データの退避先キーの接頭辞（`<prefix><元キー>_<epoch>`）
  static const String backupKeyPrefix = 'kozuchi_recurring_backup_';

  const RecurringTransactionRepository();

  /// 定義一覧を信頼性つきで取得する（例外は投げない）
  Future<RecurringDefinitionsLoadResult> loadDefinitionsResult() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return RecurringDefinitionsLoadResult.parse(prefs.getString(_defsKey));
    } catch (_) {
      return RecurringDefinitionsLoadResult(
        verified: false,
        errorMessage: RecurringDefinitionsLoadResult.corruptMessage,
      );
    }
  }

  /// 全定義を取得する（後方互換。破損時は空を返す）
  ///
  /// 破損を区別したい呼出側は [loadDefinitionsResult] を使うこと。
  Future<List<RecurringTransaction>> loadDefinitions() async {
    final result = await loadDefinitionsResult();
    return result.definitions;
  }

  /// 定義一覧を丸ごと保存する
  Future<RecurringSaveResult> saveDefinitions(
    List<RecurringTransaction> definitions,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _defsKey,
        jsonEncode(definitions.map((d) => d.toJson()).toList()),
      );
      return RecurringSaveResult.success;
    } catch (_) {
      return RecurringSaveResult.blocked('定期取引の保存に失敗しました');
    }
  }

  /// 定義を追加する（同一idは置換）
  ///
  /// 既存データが破損している場合は**上書きせず** `ok=false` を返す。
  Future<RecurringSaveResult> addDefinition(
    RecurringTransaction definition,
  ) async {
    final loaded = await loadDefinitionsResult();
    if (!loaded.verified) return RecurringSaveResult.blocked();

    final updated = [
      ...loaded.definitions.where((d) => d.id != definition.id),
      definition,
    ];
    return saveDefinitions(updated);
  }

  /// 定義を削除する（破損時は上書きしない）
  Future<RecurringSaveResult> removeDefinition(String id) async {
    final loaded = await loadDefinitionsResult();
    if (!loaded.verified) return RecurringSaveResult.blocked();

    return saveDefinitions(
      loaded.definitions.where((d) => d.id != id).toList(),
    );
  }

  /// 最終生成日時を信頼性つきで取得する（例外は投げない）
  Future<RecurringLastGeneratedResult> loadLastGeneratedResult() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return RecurringLastGeneratedResult.parse(prefs.getString(_lastGenKey));
    } catch (_) {
      return RecurringLastGeneratedResult(
        verified: false,
        errorMessage: RecurringLastGeneratedResult.corruptMessage,
      );
    }
  }

  /// 指定定義の最終生成日時を取得する（未生成・破損なら null／後方互換）
  Future<DateTime?> loadLastGenerated(String id) async {
    final result = await loadLastGeneratedResult();
    return result.valueFor(id);
  }

  /// 指定定義の最終生成日時を保存する
  ///
  /// 既存の進捗データが破損している場合は**他の定義の記録を消さないため**
  /// 上書きせず `ok=false` を返す。
  Future<RecurringSaveResult> saveLastGenerated(
    String id,
    DateTime timestamp,
  ) async {
    final loaded = await loadLastGeneratedResult();
    if (!loaded.verified) return RecurringSaveResult.blocked();

    try {
      final prefs = await SharedPreferences.getInstance();
      final map = <String, dynamic>{
        for (final e in loaded.values.entries)
          e.key: e.value.toIso8601String(),
        id: timestamp.toIso8601String(),
      };
      await prefs.setString(_lastGenKey, jsonEncode(map));
      return RecurringSaveResult.success;
    } catch (_) {
      return RecurringSaveResult.blocked('生成進捗の保存に失敗しました');
    }
  }

  /// 破損した保存データを退避キーへ移し、元キーを空ける。
  ///
  /// 退避した文字列は削除しない（復旧の余地を残す）。破損が無ければ
  /// 何もせず `false` を返す。
  Future<bool> archiveCorruptData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var archived = false;
      final stamp = DateTime.now().microsecondsSinceEpoch;

      for (final key in <String>[_defsKey, _lastGenKey]) {
        final raw = prefs.getString(key);
        if (raw == null) continue;
        final corrupt = key == _defsKey
            ? !(await loadDefinitionsResult()).verified
            : !(await loadLastGeneratedResult()).verified;
        if (!corrupt) continue;

        await prefs.setString('$backupKeyPrefix${key}_$stamp', raw);
        await prefs.remove(key);
        archived = true;
      }
      return archived;
    } catch (_) {
      return false;
    }
  }
}
