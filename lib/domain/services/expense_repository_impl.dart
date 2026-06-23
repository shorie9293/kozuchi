import 'dart:convert';
import '../models/expense_entry.dart';
import 'expense_repository.dart';

/// インメモリ実装の ExpenseRepository
///
/// テスト用。データはメモリ上にのみ保持され、プロセス終了で消える。
class InMemoryExpenseRepository implements ExpenseRepository {
  final List<ExpenseEntry> _entries = [];

  @override
  Future<List<ExpenseEntry>> getEntries({
    required DateTime start,
    required DateTime end,
  }) async {
    final startDay = _dayOnly(start);
    final endDay = _dayOnly(end);
    return _entries.where((e) {
      final entryDay = _dayOnly(e.date);
      return !entryDay.isBefore(startDay) && !entryDay.isAfter(endDay);
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  Future<void> saveEntry(ExpenseEntry entry) async {
    final index = _entries.indexWhere((e) => e.id == entry.id);
    if (index >= 0) {
      _entries[index] = entry;
    } else {
      _entries.add(entry);
    }
  }

  @override
  Future<void> saveEntries(List<ExpenseEntry> entries) async {
    for (final entry in entries) {
      await saveEntry(entry);
    }
  }

  @override
  Future<int> getEntryCount() async => _entries.length;

  @override
  Future<void> clearAll() async => _entries.clear();

  DateTime _dayOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}

/// SharedPreferences 実装の ExpenseRepository
///
/// 実際のアプリで使用する永続化実装。
/// Kozuchiアプリの SharedPreferences インスタンスを注入して使用する。
class SharedPrefsExpenseRepository implements ExpenseRepository {
  static const String _storageKey = 'kozuchi_expense_entries';

  final Future<Map<String, dynamic>> Function() _getPrefs;
  final Future<void> Function(String key, String value) _setString;

  /// [getPrefs] は全キーを読み出す関数
  /// [setString] はキーに値を書き込む関数
  SharedPrefsExpenseRepository({
    required Future<Map<String, dynamic>> Function() getPrefs,
    required Future<void> Function(String key, String value) setString,
  })  : _getPrefs = getPrefs,
        _setString = setString;

  Future<List<ExpenseEntry>> _loadAll() async {
    final prefs = await _getPrefs();
    final jsonStr = prefs[_storageKey] as String?;
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final List<dynamic> jsonList = jsonDecode(jsonStr) as List<dynamic>;
      return jsonList
          .map((e) => ExpenseEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveAll(List<ExpenseEntry> entries) async {
    final jsonList = entries.map((e) => e.toJson()).toList();
    await _setString(_storageKey, jsonEncode(jsonList));
  }

  @override
  Future<List<ExpenseEntry>> getEntries({
    required DateTime start,
    required DateTime end,
  }) async {
    final all = await _loadAll();
    final startDay = _dayOnly(start);
    final endDay = _dayOnly(end);
    return all.where((e) {
      final entryDay = _dayOnly(e.date);
      return !entryDay.isBefore(startDay) && !entryDay.isAfter(endDay);
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  Future<void> saveEntry(ExpenseEntry entry) async {
    final all = await _loadAll();
    final index = all.indexWhere((e) => e.id == entry.id);
    if (index >= 0) {
      all[index] = entry;
    } else {
      all.add(entry);
    }
    await _saveAll(all);
  }

  @override
  Future<void> saveEntries(List<ExpenseEntry> entries) async {
    final all = await _loadAll();
    for (final entry in entries) {
      final index = all.indexWhere((e) => e.id == entry.id);
      if (index >= 0) {
        all[index] = entry;
      } else {
        all.add(entry);
      }
    }
    await _saveAll(all);
  }

  @override
  Future<int> getEntryCount() async {
    final all = await _loadAll();
    return all.length;
  }

  @override
  Future<void> clearAll() async {
    await _setString(_storageKey, '[]');
  }

  DateTime _dayOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}
