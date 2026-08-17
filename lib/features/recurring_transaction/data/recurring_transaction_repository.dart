import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/features/recurring_transaction/domain/recurring_transaction.dart';

/// 定期取引定義と生成進捗の永続化リポジトリ
///
/// 定義一覧（`kozuchi_recurring_defs`）と、定義IDごとの
/// 最終生成日時（`kozuchi_recurring_last_generated`）を保存する。
class RecurringTransactionRepository {
  static const String _defsKey = 'kozuchi_recurring_defs';
  static const String _lastGenKey = 'kozuchi_recurring_last_generated';

  const RecurringTransactionRepository();

  /// 全定義を取得する
  Future<List<RecurringTransaction>> loadDefinitions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_defsKey);
    if (jsonString == null) return [];
    try {
      final list = jsonDecode(jsonString) as List<dynamic>;
      return list
          .map((e) => RecurringTransaction.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// 定義一覧を丸ごと保存する
  Future<void> saveDefinitions(List<RecurringTransaction> definitions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _defsKey,
      jsonEncode(definitions.map((d) => d.toJson()).toList()),
    );
  }

  /// 定義を追加する（同一idは置換）
  Future<void> addDefinition(RecurringTransaction definition) async {
    final current = await loadDefinitions();
    final updated = [
      ...current.where((d) => d.id != definition.id),
      definition,
    ];
    await saveDefinitions(updated);
  }

  /// 定義を削除する
  Future<void> removeDefinition(String id) async {
    final current = await loadDefinitions();
    await saveDefinitions(current.where((d) => d.id != id).toList());
  }

  /// 指定定義の最終生成日時を取得する（未生成なら null）
  Future<DateTime?> loadLastGenerated(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_lastGenKey);
    if (jsonString == null) return null;
    try {
      final map = jsonDecode(jsonString) as Map<String, dynamic>;
      final v = map[id];
      if (v is String) return DateTime.tryParse(v);
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 指定定義の最終生成日時を保存する
  Future<void> saveLastGenerated(String id, DateTime timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_lastGenKey);
    Map<String, dynamic> map = {};
    if (jsonString != null) {
      try {
        map = (jsonDecode(jsonString) as Map<String, dynamic>);
      } catch (_) {
        map = {};
      }
    }
    map[id] = timestamp.toIso8601String();
    await prefs.setString(_lastGenKey, jsonEncode(map));
  }
}
