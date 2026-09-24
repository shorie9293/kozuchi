import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:kozuchi/features/category_ledger/domain/category_ledger.dart';

/// カテゴリ台帳の永続化抽象
abstract interface class CategoryLedgerRepository {
  /// 台帳を読み出す（未保存・破損時は既定台帳）。
  Future<CategoryLedger> loadLedger();

  /// 台帳を保存する。
  Future<void> saveLedger(CategoryLedger ledger);
}

/// SharedPreferences 実装
///
/// キー `kozuchi_category_ledger` にシンプルな JSON 文字列リストとして
/// 保存する。未保存・破損時は既定台帳にフォールバックし例外を投げない。
class SharedPreferencesCategoryLedgerRepository
    implements CategoryLedgerRepository {
  /// 永続化キー
  static const String storageKey = 'kozuchi_category_ledger';

  const SharedPreferencesCategoryLedgerRepository();

  @override
  Future<CategoryLedger> loadLedger() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(storageKey);
    if (jsonString == null) return CategoryLedger.defaults();

    try {
      final decoded = jsonDecode(jsonString);
      return CategoryLedger.tryFromJson(decoded) ?? CategoryLedger.defaults();
    } catch (_) {
      return CategoryLedger.defaults();
    }
  }

  @override
  Future<void> saveLedger(CategoryLedger ledger) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(ledger.toJson()));
  }
}

/// 試練用のメモリ内リポジトリ
class InMemoryCategoryLedgerRepository implements CategoryLedgerRepository {
  /// 保存内容（試練の検証に使える）
  CategoryLedger? stored;

  @override
  Future<CategoryLedger> loadLedger() async {
    return stored ?? CategoryLedger.defaults();
  }

  @override
  Future<void> saveLedger(CategoryLedger ledger) async {
    stored = ledger;
  }
}

/// 何もしないリポジトリ（load常に既定 / saveは何もしない）
class NoopCategoryLedgerRepository implements CategoryLedgerRepository {
  const NoopCategoryLedgerRepository();

  @override
  Future<CategoryLedger> loadLedger() async => CategoryLedger.defaults();

  @override
  Future<void> saveLedger(CategoryLedger ledger) async {}
}