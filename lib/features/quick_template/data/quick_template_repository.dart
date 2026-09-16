import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:kozuchi/features/quick_template/domain/models/expense_template.dart';

/// クイックテンプレートの永続化抽象
///
/// 破損データは読み飛ばし、例外を投げない。
abstract interface class QuickTemplateRepository {
  /// テンプレート一覧を読み出す（未保存・破損時は空/部分リスト）。
  Future<List<ExpenseTemplate>> loadTemplates();

  /// テンプレート一覧を保存する。
  Future<void> saveTemplates(List<ExpenseTemplate> templates);
}

/// SharedPreferences 実装
///
/// キー `kozuchi_quick_templates` に JSON 文字列として保存する。
/// 要素単位の破損（amount<=0 など）は [ExpenseTemplate.tryFromJson] で
/// 生マップを検証して読み飛ばすため、assert 由来の例外で全滅しない。
class SharedPreferencesQuickTemplateRepository
    implements QuickTemplateRepository {
  /// 永続化キー
  static const String storageKey = 'kozuchi_quick_templates';

  const SharedPreferencesQuickTemplateRepository();

  @override
  Future<List<ExpenseTemplate>> loadTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(storageKey);
    if (jsonString == null) return const [];

    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! List) return const [];
      final templates = <ExpenseTemplate>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          _tryAdd(templates, item);
        } else if (item is Map) {
          _tryAdd(templates, Map<String, dynamic>.from(item));
        }
      }
      return List.unmodifiable(templates);
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> saveTemplates(List<ExpenseTemplate> templates) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      storageKey,
      jsonEncode(templates.map((t) => t.toJson()).toList()),
    );
  }

  /// 生マップを検証してから追加する（破損要素は読み飛ばす）。
  void _tryAdd(List<ExpenseTemplate> templates, Map<String, dynamic> raw) {
    try {
      final template = ExpenseTemplate.tryFromJson(raw);
      if (template != null) templates.add(template);
    } catch (_) {
      // 破損要素は読み飛ばす
    }
  }
}

/// 試練用のメモリ内リポジトリ
///
/// 実 I/O を伴わず、保存内容はメモリ上のリストに保持する。
class InMemoryQuickTemplateRepository implements QuickTemplateRepository {
  /// 保存内容のスナップショット（試練の検証に使える）
  final List<ExpenseTemplate> stored = [];

  @override
  Future<List<ExpenseTemplate>> loadTemplates() async {
    return List.unmodifiable(stored);
  }

  @override
  Future<void> saveTemplates(List<ExpenseTemplate> templates) async {
    stored
      ..clear()
      ..addAll(templates);
  }
}
