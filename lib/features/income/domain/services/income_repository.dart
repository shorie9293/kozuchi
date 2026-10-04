import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/income_entry.dart';

/// 収入データの永続化インターフェース
///
/// [ExpenseRepository] と対になる収入版リポジトリ。
/// 収入は端末ローカル（SharedPreferences）のみで同期しない。
abstract class IncomeRepository {
  /// 全収入エントリを返す（date 昇順）。
  Future<List<IncomeEntry>> getAllEntries();

  /// 収入エントリを保存する（同IDは上書き）。
  Future<void> saveEntry(IncomeEntry entry);

  /// 全データを削除する（リセット用）。
  Future<void> clearAll();
}

/// インメモリ実装の IncomeRepository（テスト用）。
class InMemoryIncomeRepository implements IncomeRepository {
  final List<IncomeEntry> _entries = [];

  @override
  Future<List<IncomeEntry>> getAllEntries() async {
    final entries = [..._entries]
      ..sort((a, b) => a.date.compareTo(b.date));
    return entries;
  }

  @override
  Future<void> saveEntry(IncomeEntry entry) async {
    final index = _entries.indexWhere((e) => e.id == entry.id);
    if (index >= 0) {
      _entries[index] = entry;
    } else {
      _entries.add(entry);
    }
  }

  @override
  Future<void> clearAll() async {
    _entries.clear();
  }
}

/// 何もしない IncomeRepository。
///
/// Hive/SharedPreferences 未初期化の環境（試練等）で
/// 永続化に触れずに記録フローを成立させるための既定実装。
class NoopIncomeRepository implements IncomeRepository {
  const NoopIncomeRepository();

  @override
  Future<List<IncomeEntry>> getAllEntries() async => const [];

  @override
  Future<void> saveEntry(IncomeEntry entry) async {}

  @override
  Future<void> clearAll() async {}
}

/// SharedPreferences 実装の IncomeRepository。
///
/// JSONリストとして key `income_entries` に保存する。
/// 破損JSONは既定（空リスト）へフォールバックし、
/// 要素単位の読み飛ばしで部分的な破損にも耐える。
class SharedPreferencesIncomeRepository implements IncomeRepository {
  static const String storageKey = 'income_entries';

  final SharedPreferences prefs;

  const SharedPreferencesIncomeRepository(this.prefs);

  @override
  Future<List<IncomeEntry>> getAllEntries() async {
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final entries = <IncomeEntry>[];
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) continue;
        try {
          entries.add(IncomeEntry.fromJson(item));
        } catch (_) {
          // 破損要素は読み飛ばす
        }
      }
      entries.sort((a, b) => a.date.compareTo(b.date));
      return entries;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> saveEntry(IncomeEntry entry) async {
    final entries = await getAllEntries();
    final index = entries.indexWhere((e) => e.id == entry.id);
    if (index >= 0) {
      entries[index] = entry;
    } else {
      entries.add(entry);
    }
    await prefs.setString(
      storageKey,
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }

  @override
  Future<void> clearAll() async {
    await prefs.remove(storageKey);
  }
}
